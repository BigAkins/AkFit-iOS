import SwiftUI
import Supabase

/// Sheet for editing the user's goal type, activity level, pace, and the
/// resulting calorie and macro targets.
///
/// Presented from `SettingsView`. Pre-populates from the current active
/// `UserGoal` and `UserProfile` using `OnboardingData.from(goal:profile:)`.
///
/// **Body stats are not edited here.** Weight, height, birthdate, and sex
/// live in `EditProfileView`. The existing profile values flow through to
/// `MacroCalculator` automatically — the user only adjusts goal parameters.
///
/// **Live preview:** calorie and macro numbers update as the user changes any
/// picker — they see exactly what their new targets will be before committing.
///
/// **Persistence:**
/// - PATCHes the `goals` row with the new goal type, pace, and recalculated
///   daily targets.
/// - PATCHes `profiles.activity_level` so the value stays in sync with what
///   `EditProfileView` reads back on next open.
struct EditGoalView: View {
    let goal: UserGoal
    let profile: UserProfile?

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss)        private var dismiss

    @State private var draft: OnboardingData
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    init(goal: UserGoal, profile: UserProfile? = nil) {
        self.goal    = goal
        self.profile = profile
        _draft = State(initialValue: OnboardingData.from(goal: goal, profile: profile))
    }

    // MARK: - Derived

    private var calculated: MacroCalculator.Output? {
        draft.calculatorInput.map { MacroCalculator.calculate($0) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ── Live target preview ──────────────────────────────────
                if let out = calculated {
                    Section {
                        targetPreview(out)
                    } header: {
                        Text("Your new daily targets")
                    }
                }

                // ── Goal parameters ──────────────────────────────────────
                Section("Goal") {
                    Picker("Goal type", selection: $draft.goalType) {
                        Text("Fat Loss")   .tag(Optional(UserGoal.GoalType.fatLoss))
                        Text("Maintenance").tag(Optional(UserGoal.GoalType.maintenance))
                        Text("Lean Bulk")  .tag(Optional(UserGoal.GoalType.leanBulk))
                    }
                    .onChange(of: draft.goalType) { _, newValue in
                        if newValue == .maintenance { draft.pace = .moderate }
                    }

                    Picker("Activity level", selection: $draft.activityLevel) {
                        Text("Sedentary")         .tag(Optional(UserGoal.ActivityLevel.sedentary))
                        Text("Lightly Active")    .tag(Optional(UserGoal.ActivityLevel.light))
                        Text("Moderately Active") .tag(Optional(UserGoal.ActivityLevel.moderate))
                        Text("Active")            .tag(Optional(UserGoal.ActivityLevel.active))
                        Text("Very Active")       .tag(Optional(UserGoal.ActivityLevel.veryActive))
                    }

                    if draft.goalType != .maintenance {
                        Picker("Pace", selection: $draft.pace) {
                            Text(UserGoal.Pace.slow    .displayName).tag(UserGoal.Pace.slow)
                            Text(UserGoal.Pace.moderate.displayName).tag(UserGoal.Pace.moderate)
                            Text(UserGoal.Pace.fast    .displayName).tag(UserGoal.Pace.fast)
                        }
                    }
                }

                // ── Error message ────────────────────────────────────────
                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(calculated == nil)
                    }
                }
            }
        }
    }

    // MARK: - Live target preview

    private func targetPreview(_ out: MacroCalculator.Output) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(out.calories)")
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: out.calories)
                Text("kcal / day")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                macroLabel("P", "\(out.proteinG)g", .red)
                macroLabel("C", "\(out.carbsG)g",   .orange)
                macroLabel("F", "\(out.fatG)g",     .blue)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func macroLabel(_ initial: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(initial).fontWeight(.semibold).foregroundStyle(color)
            Text(value).foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
    }

    // MARK: - Save

    private func save() {
        guard
            let input  = draft.calculatorInput,
            let out    = calculated,
            let userId = authManager.currentUserId
        else { return }

        isSaving  = true
        saveError = nil

        Task {
            defer { isSaving = false }

            // Guest path: update locally, no Supabase.
            if authManager.isGuest {
                let now = Date()
                let updatedGoal = UserGoal(
                    id:            goal.id,
                    userId:        userId,
                    goalType:      input.goalType,
                    targetWeight:  goal.targetWeight,
                    targetPace:    input.goalType == .maintenance ? nil : input.pace,
                    dailyCalories: out.calories,
                    dailyProtein:  out.proteinG,
                    dailyCarbs:    out.carbsG,
                    dailyFat:      out.fatG,
                    createdAt:     goal.createdAt,
                    updatedAt:     now
                )
                var updatedProfile = authManager.profile ?? UserProfile(
                    id:            userId,
                    displayName:   nil,
                    heightCm:      nil,
                    weightKg:      nil,
                    birthdate:     nil,
                    sex:           nil,
                    activityLevel: nil,
                    createdAt:     now,
                    updatedAt:     now
                )
                updatedProfile.activityLevel = input.activityLevel
                updatedProfile.updatedAt     = now
                authManager.updateGoal(updatedGoal)
                authManager.updateProfile(updatedProfile)
                dismiss()
                return
            }

            // Authenticated path: validate the session first, then persist.
            do {
                let writeUserId = try await authManager.requireAuthenticatedUserIDForWrite()
                // Patch goal row with new goal type, pace, and recalculated targets.
                let updatedGoal = try await GoalService.update(
                    userId: writeUserId, goalId: goal.id, input: input, out: out
                )
                // Patch profiles.activity_level so EditProfileView stays in sync.
                let updatedProfile = try await ProfileService.patchActivityLevel(
                    userId: writeUserId, activityLevel: input.activityLevel
                )
                authManager.updateGoal(updatedGoal)
                authManager.updateProfile(updatedProfile)
                dismiss()
            } catch {
                if error is AuthError {
                    saveError = "Session expired. Please sign out and sign back in."
                } else {
                    saveError = "Couldn't save changes. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditGoalView(
        goal: UserGoal(
            id: UUID(), userId: UUID(),
            goalType: .fatLoss,
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: 2100, dailyProtein: 165,
            dailyCarbs: 220, dailyFat: 65,
            createdAt: Date(), updatedAt: Date()
        ),
        profile: UserProfile(
            id: UUID(), displayName: nil,
            heightCm: 178, weightKg: 82, birthdate: "1992-01-01",
            createdAt: Date(), updatedAt: Date()
        )
    )
    .environment(AuthManager(previewMode: true))
}
