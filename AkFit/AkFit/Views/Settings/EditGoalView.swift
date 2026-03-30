import SwiftUI
import Supabase

/// Sheet for editing the user's calorie and macro targets.
///
/// Presented from `SettingsView`. Pre-populates from the current active
/// `UserGoal` using `OnboardingData.from(goal:)`.
///
/// **Live preview:** the calorie and macro numbers at the top of the form
/// update as the user changes any input — they see exactly what their new
/// targets will be before committing.
///
/// **Persistence:** on "Save", PATCHes the existing `user_goals` row in
/// place (no new row inserted). The existing `user_goals: update own` RLS
/// policy covers this operation. After a successful save, calls
/// `authManager.updateGoal(_:)` so all views reflect the new targets
/// immediately without a refetch.
struct EditGoalView: View {
    let goal: UserGoal

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

    init(goal: UserGoal) {
        self.goal  = goal
        _draft = State(initialValue: OnboardingData.from(goal: goal))
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
                        Text("New targets")
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
                        // Keep OnboardingData consistent: pace is irrelevant for maintenance.
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
                        "Weight: \(Int(draft.weightKg.rounded())) kg",
                        value: $draft.weightKg,
                        in: 30...200,
                        step: 1
                    )
                    Stepper(
                        "Height: \(Int(draft.heightCm.rounded())) cm",
                        value: $draft.heightCm,
                        in: 130...220,
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
                let updated = try await patchGoal(userId: userId, input: input, out: out)
                authManager.updateGoal(updated)
                dismiss()
            } catch {
                saveError = "Couldn't save changes. Please try again."
            }
        }
    }

    /// PATCHes the user's active goal row in `user_goals`.
    ///
    /// The `user_goals: update own` RLS policy (using `auth.uid() = user_id`)
    /// covers this operation — no additional policy is needed.
    /// The `.eq("user_id", ...)` clause is a belt-and-suspenders guard on top of RLS.
    private func patchGoal(
        userId: UUID,
        input: MacroCalculator.Input,
        out:   MacroCalculator.Output
    ) async throws -> UserGoal {
        let payload = GoalUpdate(
            goalType:        input.goalType.rawValue,
            targetCalories:  out.calories,
            targetProteinG:  out.proteinG,
            targetCarbsG:    out.carbsG,
            targetFatG:      out.fatG,
            heightCm:        Int(input.heightCm.rounded()),
            weightKg:        Int(input.weightKg.rounded()),
            age:             input.age,
            sex:             input.sex.rawValue,
            activityLevel:   input.activityLevel.rawValue,
            pace:            input.pace.rawValue,
            updatedAt:       Date()
        )
        return try await SupabaseClientProvider.shared
            .from("user_goals")
            .update(payload)
            .eq("id",      value: goal.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}

// MARK: - Update payload

/// Encodable payload for PATCHing a `user_goals` row.
/// Excludes `id`, `user_id`, `is_active`, and `created_at` — those are immutable
/// for an in-place goal update.
private struct GoalUpdate: Encodable {
    let goalType:       String
    let targetCalories: Int
    let targetProteinG: Int
    let targetCarbsG:   Int
    let targetFatG:     Int
    let heightCm:       Int
    let weightKg:       Int
    let age:            Int
    let sex:            String
    let activityLevel:  String
    let pace:           String
    let updatedAt:      Date

    enum CodingKeys: String, CodingKey {
        case goalType       = "goal_type"
        case targetCalories = "target_calories"
        case targetProteinG = "target_protein_g"
        case targetCarbsG   = "target_carbs_g"
        case targetFatG     = "target_fat_g"
        case heightCm       = "height_cm"
        case weightKg       = "weight_kg"
        case age
        case sex
        case activityLevel  = "activity_level"
        case pace
        case updatedAt      = "updated_at"
    }
}

// MARK: - Preview

#Preview {
    EditGoalView(goal: UserGoal(
        id: UUID(), userId: UUID(),
        goalType: .fatLoss,
        targetCalories: 2100, targetProteinG: 165,
        targetCarbsG: 220,   targetFatG: 65,
        heightCm: 178, weightKg: 82, age: 32, sex: .male,
        activityLevel: .moderate, pace: .moderate,
        isActive: true, createdAt: Date(), updatedAt: Date()
    ))
    .environment(AuthManager(previewMode: true))
}
