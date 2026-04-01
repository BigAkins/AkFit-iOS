import SwiftUI
import Supabase

/// Sheet for editing the user's body stats: height, weight, birth year, and sex.
///
/// Presented from `SettingsView` via the "Edit Profile" row.
///
/// **Persistence:**
/// - Upserts the `profiles` row with updated body stats.
/// - PATCHes the `goals` row with recalculated daily macro targets so the
///   dashboard immediately reflects the change.
struct EditProfileView: View {
    let goal: UserGoal
    let profile: UserProfile?

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss)        private var dismiss

    @State private var draft: OnboardingData
    @State private var isSaving  = false
    @State private var saveError: String? = nil

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
                if let out = calculated {
                    Section {
                        targetPreview(out)
                    } header: {
                        Text("Recalculated daily targets")
                    }
                }

                Section {
                    // Display name — optional, saved to profiles.display_name.
                    TextField("Name", text: $draft.displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
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
                    Text("Profile")
                } footer: {
                    Text("Name is optional. Height, weight, age, and sex are used to calculate your daily calorie and macro targets.")
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

        let trimmedName = draft.displayName.trimmingCharacters(in: .whitespaces)
        let displayName: String? = trimmedName.isEmpty ? nil : trimmedName

        isSaving  = true
        saveError = nil

        Task {
            defer { isSaving = false }
            do {
                // Update display name + body stats in profiles.
                let updatedProfile = try await upsertProfile(userId: userId, input: input, displayName: displayName)
                // Recalculate and update macro targets in goals.
                let updatedGoal    = try await patchGoal(userId: userId, input: input, out: out)
                authManager.updateProfile(updatedProfile)
                authManager.updateGoal(updatedGoal)
                dismiss()
            } catch {
                saveError = "Couldn't save changes. Please try again."
            }
        }
    }

    /// Upserts the `profiles` row with updated display name and body stats.
    private func upsertProfile(userId: UUID, input: MacroCalculator.Input, displayName: String?) async throws -> UserProfile {
        struct ProfileUpsert: Encodable {
            let id:           UUID
            let display_name: String?
            let height_cm:    Int
            let weight_kg:    Int
            let birthdate:    String
            let updated_at:   Date
        }
        let row = ProfileUpsert(
            id:           userId,
            display_name: displayName,
            height_cm:    Int(input.heightCm.rounded()),
            weight_kg:    Int(input.weightKg.rounded()),
            birthdate:    "\(Calendar.current.component(.year, from: Date()) - input.age)-01-01",
            updated_at:   Date()
        )
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .upsert(row, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    /// PATCHes the `goals` row with recalculated daily targets.
    private func patchGoal(
        userId: UUID,
        input:  MacroCalculator.Input,
        out:    MacroCalculator.Output
    ) async throws -> UserGoal {
        struct GoalPatch: Encodable {
            let daily_calories: Int
            let daily_protein:  Int
            let daily_carbs:    Int
            let daily_fat:      Int
            let updated_at:     Date
        }
        let payload = GoalPatch(
            daily_calories: out.calories,
            daily_protein:  out.proteinG,
            daily_carbs:    out.carbsG,
            daily_fat:      out.fatG,
            updated_at:     Date()
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
}

// MARK: - Preview

#Preview {
    EditProfileView(
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
