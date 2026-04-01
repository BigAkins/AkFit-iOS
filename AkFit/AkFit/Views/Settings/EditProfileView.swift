import SwiftUI
import Supabase

/// Sheet for editing the user's body stats: display name, height, weight,
/// full birthdate, sex, and activity level.
///
/// Presented from `SettingsView` via the "Edit Profile" row.
///
/// **Persistence:**
/// - Upserts the `profiles` row with updated body stats.
/// - PATCHes the `goals` row with recalculated daily macro targets so the
///   dashboard immediately reflects the change.
///
/// **Sex / activity level:** stored in `profiles.sex` and `profiles.activity_level`
/// since migration 20260331000001. Restored from the profile on open; persisted
/// on every save alongside the other body stats.
struct EditProfileView: View {
    let goal: UserGoal
    let profile: UserProfile?

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss)        private var dismiss

    @State private var draft: OnboardingData
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    // Birthdate range: ages 15–80.
    private static let minBirthdate: Date = Calendar.current.date(
        byAdding: .year, value: -80, to: Date())!
    private static let maxBirthdate: Date = Calendar.current.date(
        byAdding: .year, value: -15, to: Date())!

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
                let clamped        = min(max(total, 48), 95)
                draft.heightFeet   = clamped / 12
                draft.heightInches = clamped % 12
            }
        )
    }

    /// Bridges the three separate Int fields (year/month/day) to a single Date
    /// used by the DatePicker. Reads from draft; writes back on change.
    private var birthdateBinding: Binding<Date> {
        Binding(
            get: {
                var c   = DateComponents()
                c.year  = draft.birthYear
                c.month = draft.birthMonth
                c.day   = draft.birthDay
                return Calendar.current.date(from: c) ?? Self.maxBirthdate
            },
            set: { date in
                let cal          = Calendar.current
                draft.birthYear  = cal.component(.year,  from: date)
                draft.birthMonth = cal.component(.month, from: date)
                draft.birthDay   = cal.component(.day,   from: date)
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
                    DatePicker(
                        "Date of birth",
                        selection: birthdateBinding,
                        in: Self.minBirthdate...Self.maxBirthdate,
                        displayedComponents: .date
                    )
                    // Segmented control: immediately visible, no navigation needed.
                    Picker("Sex", selection: $draft.sex) {
                        Text("Male")  .tag(Optional(UserGoal.Sex.male))
                        Text("Female").tag(Optional(UserGoal.Sex.female))
                    }
                    .pickerStyle(.segmented)
                    Picker("Activity level", selection: $draft.activityLevel) {
                        Text("Sedentary")        .tag(Optional(UserGoal.ActivityLevel.sedentary))
                        Text("Lightly Active")   .tag(Optional(UserGoal.ActivityLevel.light))
                        Text("Moderately Active").tag(Optional(UserGoal.ActivityLevel.moderate))
                        Text("Active")           .tag(Optional(UserGoal.ActivityLevel.active))
                        Text("Very Active")      .tag(Optional(UserGoal.ActivityLevel.veryActive))
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Name is optional. Height, weight, birthdate, sex, and activity level are used to calculate your daily calorie and macro targets.")
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
        let birthdate = String(format: "%04d-%02d-%02d",
                               draft.birthYear, draft.birthMonth, draft.birthDay)

        isSaving  = true
        saveError = nil

        Task {
            defer { isSaving = false }

            // Guest path: update locally, no Supabase.
            if authManager.isGuest {
                let now = Date()
                let updatedProfile = UserProfile(
                    id:            userId,
                    displayName:   displayName,
                    heightCm:      input.heightCm,
                    weightKg:      input.weightKg,
                    birthdate:     birthdate,
                    sex:           input.sex,
                    activityLevel: input.activityLevel,
                    createdAt:     authManager.profile?.createdAt ?? now,
                    updatedAt:     now
                )
                let updatedGoal = UserGoal(
                    id:            goal.id,
                    userId:        userId,
                    goalType:      goal.goalType,
                    targetWeight:  goal.targetWeight,
                    targetPace:    goal.targetPace,
                    dailyCalories: out.calories,
                    dailyProtein:  out.proteinG,
                    dailyCarbs:    out.carbsG,
                    dailyFat:      out.fatG,
                    createdAt:     goal.createdAt,
                    updatedAt:     now
                )
                authManager.updateProfile(updatedProfile)
                authManager.updateGoal(updatedGoal)
                dismiss()
                return
            }

            // Authenticated path: persist to Supabase.
            do {
                let updatedProfile = try await upsertProfile(
                    userId: userId, input: input, displayName: displayName, birthdate: birthdate
                )
                let updatedGoal = try await patchGoal(userId: userId, input: input, out: out)
                authManager.updateProfile(updatedProfile)
                authManager.updateGoal(updatedGoal)
                dismiss()
            } catch {
                saveError = "Couldn't save changes. Please try again."
            }
        }
    }

    /// Upserts the `profiles` row with updated display name, body stats,
    /// full birthdate, sex, and activity level.
    private func upsertProfile(
        userId:      UUID,
        input:       MacroCalculator.Input,
        displayName: String?,
        birthdate:   String
    ) async throws -> UserProfile {
        struct ProfileUpsert: Encodable {
            let id:             UUID
            let display_name:   String?
            let height_cm:      Int
            let weight_kg:      Int
            let birthdate:      String
            let sex:            String
            let activity_level: String
            let updated_at:     Date
        }
        let row = ProfileUpsert(
            id:             userId,
            display_name:   displayName,
            height_cm:      Int(input.heightCm.rounded()),
            weight_kg:      Int(input.weightKg.rounded()),
            birthdate:      birthdate,
            sex:            input.sex.rawValue,
            activity_level: input.activityLevel.rawValue,
            updated_at:     Date()
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
            heightCm: 178, weightKg: 82, birthdate: "1992-06-15",
            createdAt: Date(), updatedAt: Date()
        )
    )
    .environment(AuthManager(previewMode: true))
}
