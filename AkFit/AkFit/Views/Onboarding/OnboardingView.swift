import SwiftUI

/// Multi-step onboarding flow.
///
/// Step order:
///   1. Sex selection
///   2. Body stats (birth year · height · weight)
///   3. Goal type
///   4. Activity level
///   5. Pace  (skipped for maintenance)
///   6. Results + persist
struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var data = OnboardingData()
    @State private var step: Step = .sex

    enum Step: Int, CaseIterable {
        case sex, bodyStats, goal, activity, pace, results
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            stepContent
        }
        .background(Color(UIColor.systemBackground))
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color(.systemGray5)
                Color.primary
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.spring(duration: 0.4), value: step)
            }
        }
        .frame(height: 3)
    }

    private var progressFraction: Double {
        let totalSteps = visibleSteps.count
        let currentIndex = visibleSteps.firstIndex(of: step) ?? 0
        return totalSteps > 1 ? Double(currentIndex + 1) / Double(totalSteps) : 1
    }

    private var visibleSteps: [Step] {
        var steps: [Step] = [.sex, .bodyStats, .goal, .activity]
        if data.goalType != .maintenance { steps.append(.pace) }
        steps.append(.results)
        return steps
    }

    // MARK: - Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .sex:       SexStepView(data: data, onNext: advance)
        case .bodyStats: BodyStatsStepView(data: data, onNext: advance)
        case .goal:      GoalStepView(data: data, onNext: advance)
        case .activity:  ActivityStepView(data: data, onNext: advance)
        case .pace:      PaceStepView(data: data, onNext: advance)
        case .results:   ResultsStepView(data: data, authManager: authManager)
        }
    }

    private func advance() {
        let steps = visibleSteps
        guard let idx = steps.firstIndex(of: step), idx + 1 < steps.count else { return }
        step = steps[idx + 1]
    }
}

// MARK: - Shared layout helpers

private struct OnboardingStepLayout<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)

            content()
                .frame(maxHeight: .infinity, alignment: .center)

            footer()
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
    }
}

private func ctaButton(label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(disabled ? Color(.systemGray4) : Color.primary)
            .foregroundStyle(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .disabled(disabled)
}

// MARK: - Step 1: Sex

private struct SexStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(title: "What's your\nbiological sex?", subtitle: "Used to calculate your metabolic rate.") {
            VStack(spacing: 12) {
                ForEach([UserGoal.Sex.male, .female], id: \.self) { option in
                    SelectionCard(
                        title: option == .male ? "Male" : "Female",
                        isSelected: data.sex == option
                    ) { data.sex = option }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            ctaButton(label: "Continue", disabled: data.sex == nil) { onNext() }
        }
    }
}

// MARK: - Step 2: Body stats

private struct BodyStatsStepView: View {
    @Bindable var data: OnboardingData

    let onNext: () -> Void

    private let yearRange: [Int] = Array((Calendar.current.component(.year, from: Date()) - 80)...(Calendar.current.component(.year, from: Date()) - 15))
    private let heightRange: [Double] = stride(from: 130.0, through: 220.0, by: 0.5).map { $0 }
    private let weightRange: [Double] = stride(from: 30.0, through: 200.0, by: 0.5).map { $0 }

    var body: some View {
        OnboardingStepLayout(title: "Body stats", subtitle: "All data stays on your device until you save.") {
            VStack(spacing: 0) {
                statRow(label: "Birth year") {
                    Picker("Birth year", selection: $data.birthYear) {
                        ForEach(yearRange.reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                Divider().padding(.horizontal, 24)
                statRow(label: "Height") {
                    Picker("Height (cm)", selection: $data.heightCm) {
                        ForEach(heightRange, id: \.self) { Text(String(format: "%.1f cm", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                Divider().padding(.horizontal, 24)
                statRow(label: "Weight") {
                    Picker("Weight (kg)", selection: $data.weightKg) {
                        ForEach(weightRange, id: \.self) { Text(String(format: "%.1f kg", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
            }
        } footer: {
            ctaButton(label: "Continue") { onNext() }
        }
    }

    @ViewBuilder
    private func statRow<P: View>(label: String, @ViewBuilder picker: @escaping () -> P) -> some View {
        HStack {
            Text(label)
                .font(.body.weight(.medium))
                .frame(width: 90, alignment: .leading)
                .padding(.leading, 24)
            picker()
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Step 3: Goal

private struct GoalStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(title: "What's your\nprimary goal?") {
            VStack(spacing: 12) {
                ForEach(UserGoal.GoalType.allCases, id: \.self) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: goalSubtitle(option),
                        isSelected: data.goalType == option
                    ) {
                        data.goalType = option
                        if option == .maintenance { data.pace = .moderate }
                    }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            ctaButton(label: "Continue", disabled: data.goalType == nil) { onNext() }
        }
    }

    private func goalSubtitle(_ goal: UserGoal.GoalType) -> String {
        switch goal {
        case .fatLoss:     "Reduce body fat while preserving muscle"
        case .maintenance: "Maintain current weight and body composition"
        case .leanBulk:    "Build muscle with minimal fat gain"
        }
    }
}

// MARK: - Step 4: Activity

private struct ActivityStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(title: "How active are\nyou day-to-day?") {
            VStack(spacing: 12) {
                ForEach([
                    UserGoal.ActivityLevel.sedentary,
                    .light, .moderate, .active, .veryActive
                ], id: \.self) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: activitySubtitle(option),
                        isSelected: data.activityLevel == option
                    ) { data.activityLevel = option }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            ctaButton(label: "Continue", disabled: data.activityLevel == nil) { onNext() }
        }
    }

    private func activitySubtitle(_ level: UserGoal.ActivityLevel) -> String {
        switch level {
        case .sedentary:  "Desk job, little or no exercise"
        case .light:      "Light exercise 1–3 days/week"
        case .moderate:   "Moderate exercise 3–5 days/week"
        case .active:     "Hard exercise 6–7 days/week"
        case .veryActive: "Physical job or twice-daily training"
        }
    }
}

// MARK: - Step 5: Pace (skipped for maintenance)

private struct PaceStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    private var paceTitle: String {
        data.goalType == .leanBulk ? "How fast do you\nwant to bulk?" : "How fast do you\nwant to lose fat?"
    }

    var body: some View {
        OnboardingStepLayout(title: paceTitle) {
            VStack(spacing: 12) {
                ForEach([UserGoal.Pace.slow, .moderate, .fast], id: \.self) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: paceSubtitle(option),
                        isSelected: data.pace == option
                    ) { data.pace = option }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            ctaButton(label: "Continue") { onNext() }
        }
    }

    private func paceSubtitle(_ pace: UserGoal.Pace) -> String {
        guard let goalType = data.goalType else { return "" }
        switch (goalType, pace) {
        case (.fatLoss, .slow):     return "−250 kcal/day · easier to sustain"
        case (.fatLoss, .moderate): return "−500 kcal/day · proven sweet spot"
        case (.fatLoss, .fast):     return "−750 kcal/day · aggressive, monitor energy"
        case (.leanBulk, .slow):    return "+150 kcal/day · minimal fat gain"
        case (.leanBulk, .moderate): return "+300 kcal/day · steady gains"
        case (.leanBulk, .fast):    return "+500 kcal/day · maximize muscle growth"
        default:                    return ""
        }
    }
}

// MARK: - Step 6: Results + Persist

private struct ResultsStepView: View {
    let data: OnboardingData
    let authManager: AuthManager

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private var output: MacroCalculator.Output? {
        data.calculatorInput.map { MacroCalculator.calculate($0) }
    }

    var body: some View {
        OnboardingStepLayout(
            title: "Your daily\ntargets.",
            subtitle: "Based on your stats and goal. You can adjust these later."
        ) {
            if let out = output {
                VStack(spacing: 16) {
                    MacroResultRow(label: "Calories", value: "\(out.calories)", unit: "kcal", isPrimary: true)
                    Divider().padding(.horizontal, 24)
                    HStack(spacing: 12) {
                        MacroChip(label: "Protein", value: "\(out.proteinG)g")
                        MacroChip(label: "Carbs",   value: "\(out.carbsG)g")
                        MacroChip(label: "Fat",     value: "\(out.fatG)g")
                    }
                    .padding(.horizontal, 24)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        } footer: {
            ctaButton(label: isSaving ? "Saving…" : "Start tracking", disabled: isSaving || output == nil) {
                save()
            }
        }
    }

    private func save() {
        guard
            let out = output,
            let input = data.calculatorInput,
            let userId = authManager.session?.user.id
        else { return }

        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                // Upsert profile (display_name left nil; can be added later).
                let profile = try await upsertProfile(userId: userId)

                // Insert active goal row.
                let goal = try await insertGoal(userId: userId, input: input, out: out)

                // Route to MainTabView — no extra network fetch needed.
                authManager.markOnboarded(goal: goal, profile: profile)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func upsertProfile(userId: UUID) async throws -> UserProfile {
        struct ProfileInsert: Encodable {
            let id: UUID
        }
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .upsert(ProfileInsert(id: userId), onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    private func insertGoal(userId: UUID, input: MacroCalculator.Input, out: MacroCalculator.Output) async throws -> UserGoal {
        struct GoalInsert: Encodable {
            let user_id: UUID
            let goal_type: String
            let target_calories: Int
            let target_protein_g: Int
            let target_carbs_g: Int
            let target_fat_g: Int
            let height_cm: Double
            let weight_kg: Double
            let age: Int
            let sex: String
            let activity_level: String
            let pace: String
            let is_active: Bool
        }
        let row = GoalInsert(
            user_id:          userId,
            goal_type:        input.goalType.rawValue,
            target_calories:  out.calories,
            target_protein_g: out.proteinG,
            target_carbs_g:   out.carbsG,
            target_fat_g:     out.fatG,
            height_cm:        input.heightCm,
            weight_kg:        input.weightKg,
            age:              input.age,
            sex:              input.sex.rawValue,
            activity_level:   input.activityLevel.rawValue,
            pace:             input.pace.rawValue,
            is_active:        true
        )
        return try await SupabaseClientProvider.shared
            .from("user_goals")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }
}

// MARK: - Reusable sub-views

private struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MacroResultRow: View {
    let label: String
    let value: String
    let unit: String
    var isPrimary: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label)
                .font(isPrimary ? .title3.weight(.semibold) : .body)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(isPrimary ? .system(size: 44, weight: .bold) : .title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }
}

private struct MacroChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AuthManager(previewMode: true))
}
