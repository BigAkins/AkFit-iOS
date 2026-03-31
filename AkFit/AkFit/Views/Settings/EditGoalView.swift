import SwiftUI
import Supabase

/// Sheet for editing the user's calorie and macro targets.
///
/// Presented from `SettingsView`. Pre-populates from the current active
/// `UserGoal` and `UserProfile` using `OnboardingData.from(goal:profile:)`.
///
/// **Live preview:** the calorie and macro numbers at the top of the form
/// update as the user changes any input — they see exactly what their new
/// targets will be before committing.
///
/// **Persistence:** PATCHes the existing `goals` row in place (no new row
/// inserted), then upserts the `profiles` row with updated body stats.
struct EditGoalView: View {
    let goal: UserGoal
    let profile: UserProfile?

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss)        private var dismiss

    @State private var draft: OnboardingData
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    // Pre-computed year range for the birth year picker.
    private static let currentYear = Calendar.current.component(.year, from: Date())
    private static let yearRange   = Array(stride(
        from: currentYear - 80, through: currentYear - 15, by: 1
    ))

    init(goal: UserGoal, profile: UserProfile? = nil) {
        self.goal    = goal
        self.profile = profile
        _draft = State(initialValue: OnboardingData.from(goal: goal, profile: profile))
    }

    // MARK: - Derived

    private var calculated: MacroCalculator.Output? {
        draft.calculatorInput.map { MacroCalculator.calculate($0) }
    }

    private var totalInchesBinding: Binding<Int> {
        Binding(
            get: { draft.heightFeet * 12 + draft.heightInches },
            set: { total in
                let clamped         = min(max(total, 48), 95)
                draft.heightFeet   = clamped / 12
                draft.heightInches = clamped % 12
            }
        )
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

                // ── Body stats ───────────────────────────────────────────
                Section("Body stats") {
                    Stepper(
                        "Weight: \(draft.weightLbs) lbs",
                        value: $draft.weightLbs,
                        in: 66...440,
                        step: 1
                    )
                    Stepper(
                        "Height: \(draft.heightFeet)′ \(draft.heightInches)″",
                        value: totalInchesBinding,
                        in: 48...95,
                        step: 1
                    )
                    Picker("Born in", selection: $draft.birthYear) {
                        ForEach(Self.yearRange.reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    Picker("Sex", selection: $draft.sex) {
                        Text("Male")  .tag(Optional(UserGoal.Sex.male))
                        Text("Female").tag(Optional(UserGoal.Sex.female))
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
            do {
                // Patch the goal row with updated targets.
                let updated = try await patchGoal(userId: userId, input: input, out: out)
                // Upsert profile with updated body stats.
                let updatedProfile = try await upsertProfile(userId: userId, input: input)
                authManager.updateGoal(updated)
                authManager.updateProfile(updatedProfile)
                dismiss()
            } catch {
                saveError = "Couldn't save changes. Please try again."
            }
        }
    }

    /// PATCHes the user's active goal row in `goals`.
    private func patchGoal(
        userId: UUID,
        input: MacroCalculator.Input,
        out:   MacroCalculator.Output
    ) async throws -> UserGoal {
        let payload = GoalUpdate(
            goalType:      input.goalType.rawValue,
            targetPace:    input.pace.rawValue,
            dailyCalories: out.calories,
            dailyProtein:  out.proteinG,
            dailyCarbs:    out.carbsG,
            dailyFat:      out.fatG,
            updatedAt:     Date()
        )
        return try await SupabaseClientProvider.shared
            .from("goals")
            .update(payload)
            .eq("id",      value: goal.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    /// Upserts the `profiles` row with updated body stats.
    private func upsertProfile(userId: UUID, input: MacroCalculator.Input) async throws -> UserProfile {
        struct ProfileUpdate: Encodable {
            let id:         UUID
            let height_cm:  Int
            let weight_kg:  Int
            let birthdate:  String
            let updated_at: Date
        }
        let row = ProfileUpdate(
            id:         userId,
            height_cm:  Int(input.heightCm.rounded()),
            weight_kg:  Int(input.weightKg.rounded()),
            birthdate:  "\(Calendar.current.component(.year, from: Date()) - input.age)-01-01",
            updated_at: Date()
        )
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .upsert(row, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }
}

// MARK: - Goal update payload

/// Encodable payload for PATCHing a `goals` row.
private struct GoalUpdate: Encodable {
    let goalType:      String
    let targetPace:    String
    let dailyCalories: Int
    let dailyProtein:  Int
    let dailyCarbs:    Int
    let dailyFat:      Int
    let updatedAt:     Date

    enum CodingKeys: String, CodingKey {
        case goalType      = "goal_type"
        case targetPace    = "target_pace"
        case dailyCalories = "daily_calories"
        case dailyProtein  = "daily_protein"
        case dailyCarbs    = "daily_carbs"
        case dailyFat      = "daily_fat"
        case updatedAt     = "updated_at"
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
