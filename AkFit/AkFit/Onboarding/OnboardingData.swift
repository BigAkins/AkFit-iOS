import Foundation

/// Local state container for the onboarding flow.
///
/// Passed through the step views via the environment. Once all required
/// fields are set, `calculatorInput` produces a non-nil `MacroCalculator.Input`
/// that can be fed to `MacroCalculator.calculate(_:)`.
@Observable
final class OnboardingData {

    // MARK: - Collected fields

    var sex: UserGoal.Sex?
    var birthYear: Int = Calendar.current.component(.year, from: Date()) - 30
    var heightCm: Double = 170
    var weightKg: Double = 75
    var goalType: UserGoal.GoalType?
    var activityLevel: UserGoal.ActivityLevel?
    var pace: UserGoal.Pace = .moderate

    // MARK: - Derived

    var age: Int {
        Calendar.current.component(.year, from: Date()) - birthYear
    }

    /// Returns a valid input when all required fields are set.
    var calculatorInput: MacroCalculator.Input? {
        guard
            let sex,
            let goalType,
            let activityLevel
        else { return nil }

        return MacroCalculator.Input(
            sex: sex,
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            activityLevel: activityLevel,
            goalType: goalType,
            pace: pace
        )
    }
}
