import OSLog
import SwiftUI
import Supabase

private let onboardingLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AkFit",
    category: "Onboarding"
)

/// Multi-step onboarding flow.
///
/// Step order:
///   1. Sex selection
///   2. Height & weight (birth year · height · weight)
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
            navigationHeader
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
        let steps = visibleSteps
        let idx   = steps.firstIndex(of: step) ?? 0
        return steps.count > 1 ? Double(idx + 1) / Double(steps.count) : 1
    }

    // MARK: - Back navigation

    private var navigationHeader: some View {
        HStack {
            if step != visibleSteps.first {
                Button(action: retreat) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            Spacer()
        }
        .padding(.leading, 8)
        .frame(height: 44)
    }

    // MARK: - Step list (dynamic: pace omitted for maintenance)

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

    private func retreat() {
        let steps = visibleSteps
        guard let idx = steps.firstIndex(of: step), idx > 0 else { return }
        step = steps[idx - 1]
    }
}

// MARK: - Shared step layout

/// Consistent full-screen layout for each onboarding step:
/// title/subtitle at top, content filling the middle, CTA pinned to bottom.
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
        self.title    = title
        self.subtitle = subtitle
        self.content  = content
        self.footer   = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Content — centered vertically in remaining space
            content()
                .frame(maxHeight: .infinity, alignment: .center)

            // Footer CTA
            footer()
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - CTA button

private struct CTAButton: View {
    let label: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
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
}

// MARK: - Step 1: Sex

private struct SexStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(
            title: "What's your\nbiological sex?",
            subtitle: "Used to calculate your metabolic rate."
        ) {
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
            CTAButton(label: "Continue", disabled: data.sex == nil, action: onNext)
        }
    }
}

// MARK: - Step 2: Body stats

private struct BodyStatsStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    // Ranges computed once — values are stable for the app session.
    private static let thisYear       = Calendar.current.component(.year, from: Date())
    private static let yearRange      = Array(stride(from: thisYear - 80, through: thisYear - 15, by: 1))
    private static let feetRange      = Array(4...7)
    private static let inchesRange    = Array(0...11)
    private static let weightLbsRange = Array(66...440)   // 30–200 kg

    var body: some View {
        OnboardingStepLayout(
            title: "Height & weight",
            subtitle: "Used to calculate your calorie and macro targets."
        ) {
            VStack(spacing: 0) {
                // Birth year — compact row
                HStack {
                    Text("Born in")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Birth year", selection: $data.birthYear) {
                        ForEach(Self.yearRange.reversed(), id: \.self) {
                            Text(String($0)).tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 110, height: 96)
                    .clipped()
                }
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 24)

                // Height (ft + in) and weight (lbs) — three equal columns.
                // Internal storage stays metric; pickers bind to US-unit properties.
                HStack(spacing: 0) {

                    // ── Feet ──────────────────────────────────────────────
                    VStack(spacing: 4) {
                        Text("ft")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Feet", selection: $data.heightFeet) {
                            ForEach(Self.feetRange, id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 144)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 0.5)
                        .padding(.vertical, 16)

                    // ── Inches ────────────────────────────────────────────
                    VStack(spacing: 4) {
                        Text("in")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Inches", selection: $data.heightInches) {
                            ForEach(Self.inchesRange, id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 144)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 0.5)
                        .padding(.vertical, 16)

                    // ── Weight ────────────────────────────────────────────
                    VStack(spacing: 4) {
                        Text("lbs")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Weight", selection: $data.weightLbs) {
                            ForEach(Self.weightLbsRange, id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 144)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
        } footer: {
            CTAButton(label: "Continue", action: onNext)
        }
    }
}

// MARK: - Step 3: Goal

private struct GoalStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(title: "What is your goal?") {
            VStack(spacing: 12) {
                ForEach(UserGoal.GoalType.allCases, id: \.self) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: goalSubtitle(option),
                        isSelected: data.goalType == option
                    ) {
                        data.goalType = option
                        // Reset pace to moderate when switching to maintenance
                        // so OnboardingData stays consistent.
                        if option == .maintenance { data.pace = .moderate }
                    }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            CTAButton(label: "Continue", disabled: data.goalType == nil, action: onNext)
        }
    }

    private func goalSubtitle(_ goal: UserGoal.GoalType) -> String {
        switch goal {
        case .fatLoss:     "Reduce body fat while preserving muscle"
        case .maintenance: "Maintain current weight and composition"
        case .leanBulk:    "Build muscle with minimal fat gain"
        }
    }
}

// MARK: - Step 4: Activity

private struct ActivityStepView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void

    private let levels: [UserGoal.ActivityLevel] = [
        .sedentary, .light, .moderate, .active, .veryActive
    ]

    var body: some View {
        OnboardingStepLayout(title: "How active are\nyou day-to-day?") {
            VStack(spacing: 12) {
                ForEach(levels, id: \.self) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: activitySubtitle(option),
                        isSelected: data.activityLevel == option
                    ) { data.activityLevel = option }
                }
            }
            .padding(.horizontal, 24)
        } footer: {
            CTAButton(label: "Continue", disabled: data.activityLevel == nil, action: onNext)
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

    private var title: String {
        data.goalType == .leanBulk
            ? "How fast do you\nwant to bulk?"
            : "How fast do you\nwant to lose fat?"
    }

    var body: some View {
        OnboardingStepLayout(title: title) {
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
            CTAButton(label: "Continue", action: onNext)
        }
    }

    private func paceSubtitle(_ pace: UserGoal.Pace) -> String {
        guard let goalType = data.goalType else { return "" }
        switch (goalType, pace) {
        case (.fatLoss, .slow):      return "−250 kcal/day · easier to sustain"
        case (.fatLoss, .moderate):  return "−500 kcal/day · proven sweet spot"
        case (.fatLoss, .fast):      return "−750 kcal/day · aggressive, monitor energy"
        case (.leanBulk, .slow):     return "+150 kcal/day · minimal fat gain"
        case (.leanBulk, .moderate): return "+300 kcal/day · steady gains"
        case (.leanBulk, .fast):     return "+500 kcal/day · maximize muscle growth"
        default:                     return ""
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

    /// Short context label shown below the title, e.g. "Fat Loss · Moderate".
    ///
    /// Uses short pace names (no lb/week detail) to keep the subtitle concise.
    /// The full pace detail is shown on the pace selection step where it aids choice.
    private var contextLabel: String? {
        guard let input = data.calculatorInput else { return nil }
        if input.goalType == .maintenance { return input.goalType.displayName }
        let shortPace: String
        switch input.pace {
        case .slow:     shortPace = "Slow"
        case .moderate: shortPace = "Moderate"
        case .fast:     shortPace = "Fast"
        }
        return "\(input.goalType.displayName) · \(shortPace)"
    }

    var body: some View {
        OnboardingStepLayout(
            title: "Your daily\ntargets",
            subtitle: contextLabel
        ) {
            if let out = output {
                VStack(spacing: 0) {
                    // Calorie number — primary stat
                    VStack(spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(out.calories)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("kcal")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Text("daily calories")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)

                    // Macro chips
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
                    .padding(.top, 12)
            }
        } footer: {
            CTAButton(
                label: isSaving ? "Saving…" : "Start tracking",
                disabled: isSaving || output == nil,
                action: save
            )
        }
    }

    private func save() {
        guard
            let out    = output,
            let input  = data.calculatorInput,
            let userId = authManager.currentUserId
        else {
            onboardingLogger.error(
                "save() guard failed — output:\(output != nil) input:\(data.calculatorInput != nil) userId:\(authManager.currentUserId != nil)"
            )
            if authManager.currentUserId == nil {
                errorMessage = "Session expired. Please sign out and sign back in."
            }
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            defer { isSaving = false }
            do {
                let profile = try await upsertProfile(userId: userId)
                let goal    = try await insertGoal(userId: userId, input: input, out: out)
                authManager.markOnboarded(goal: goal, profile: profile)
            } catch {
                onboardingLogger.error(
                    "save() failed — \(String(describing: error), privacy: .public)"
                )
                errorMessage = "Couldn't save your targets. Please try again."
            }
        }
    }

    private func upsertProfile(userId: UUID) async throws -> UserProfile {
        struct ProfileInsert: Encodable { let id: UUID }
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .upsert(ProfileInsert(id: userId), onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    private func insertGoal(
        userId: UUID,
        input: MacroCalculator.Input,
        out: MacroCalculator.Output
    ) async throws -> UserGoal {
        struct GoalInsert: Encodable {
            let user_id: UUID
            let goal_type: String
            let target_calories: Int
            let target_protein_g: Int
            let target_carbs_g: Int
            let target_fat_g: Int
            let height_cm: Int
            let weight_kg: Int
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
            // Rounded to nearest integer — picker uses 1-unit steps.
            height_cm:        Int(input.heightCm.rounded()),
            weight_kg:        Int(input.weightKg.rounded()),
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

// MARK: - SelectionCard

/// A tappable card used for single-choice selections throughout onboarding.
///
/// Selected state: dark filled background + white text (matches primary reference).
/// Non-selected state: light gray background + primary text.
private struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? Color(UIColor.systemBackground) : .primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(
                                isSelected
                                    ? Color(UIColor.systemBackground).opacity(0.72)
                                    : .secondary
                            )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.primary : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MacroChip

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

#Preview("Step 1 — Sex") {
    OnboardingView()
        .environment(AuthManager(previewMode: true))
}

/// Exercises the Results step (step 6) directly, bypassing the need to
/// step through the full onboarding flow in Xcode Canvas.
#Preview("Step 6 — Results") {
    let data = OnboardingData()
    data.sex           = .male
    data.goalType      = .fatLoss
    data.activityLevel = .moderate
    data.pace          = .moderate
    // heightFeet / heightInches / weightLbs / birthYear use OnboardingData defaults.
    return ResultsStepView(data: data, authManager: AuthManager(previewMode: true))
}
