import SwiftUI
import Supabase

/// Sheet for editing the user's body stats: height, weight, birth year, and sex.
///
/// Presented from `SettingsView` via the "Edit Profile" row. Intentionally
/// scoped to body stats only — goal type, activity level, and pace are edited
/// separately via `EditGoalView`.
///
/// **Live preview:** the calorie and macro numbers at the top update as the
/// user changes any stat, so they see the recalculated targets before saving.
///
/// **Persistence:** PATCHes the existing `user_goals` row in place (same
/// mechanism as `EditGoalView`). Goal type, activity level, and pace are
/// carried through unchanged from the current goal.
struct EditProfileView: View {
    let goal: UserGoal

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss)        private var dismiss

    @State private var draft: OnboardingData
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    private static let currentYear = Calendar.current.component(.year, from: Date())
    private static let yearRange   = Array(stride(
        from: currentYear - 80, through: currentYear - 15, by: 1
    ))

    init(goal: UserGoal) {
        self.goal = goal
        _draft = State(initialValue: OnboardingData.from(goal: goal))
    }

    // MARK: - Derived

    private var calculated: MacroCalculator.Output? {
        draft.calculatorInput.map { MacroCalculator.calculate($0) }
    }

    /// Unified feet+inches as a single integer for a single Stepper control.
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
                // Live target preview — shows what the new targets will be.
                if let out = calculated {
                    Section {
                        targetPreview(out)
                    } header: {
                        Text("Recalculated daily targets")
                    }
                }

                // Body stats — the only editable fields in this sheet.
                Section {
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
                } header: {
                    Text("Body stats")
                } footer: {
                    Text("Height, weight, age, and sex are used to calculate your daily calorie and macro targets.")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
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

    /// PATCHes the user's active goal row with updated body stats and
    /// recalculated macro targets. Goal type, activity level, and pace are
    /// carried through unchanged from the current goal.
    private func patchGoal(
        userId: UUID,
        input: MacroCalculator.Input,
        out:   MacroCalculator.Output
    ) async throws -> UserGoal {
        let payload = ProfileUpdate(
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

private struct ProfileUpdate: Encodable {
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
    EditProfileView(goal: UserGoal(
        id: UUID(), userId: UUID(),
        goalType: .fatLoss,
        targetCalories: 2100, targetProteinG: 165,
        targetCarbsG: 220, targetFatG: 65,
        heightCm: 178, weightKg: 82, age: 32, sex: .male,
        activityLevel: .moderate, pace: .moderate,
        isActive: true, createdAt: Date(), updatedAt: Date()
    ))
    .environment(AuthManager(previewMode: true))
}
