import Foundation

// MARK: - OnboardingData

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

// MARK: - Settings pre-population

extension OnboardingData {
    /// Builds an `OnboardingData` pre-populated from a saved `UserGoal`.
    ///
    /// Used by `EditGoalView` to seed the edit form with the user's current
    /// goal inputs so they only need to change what they want to update.
    ///
    /// `age` is reconstructed as `currentYear − goal.age`, which gives the
    /// same approximate birth year the onboarding collected. Falls back to
    /// sensible defaults for nullable goal fields.
    static func from(goal: UserGoal) -> OnboardingData {
        let d = OnboardingData()
        d.goalType      = goal.goalType
        d.sex           = goal.sex
        d.activityLevel = goal.activityLevel
        d.pace          = goal.pace ?? .moderate
        d.heightCm      = goal.heightCm ?? 170
        d.weightKg      = goal.weightKg ?? 75
        if let age = goal.age {
            d.birthYear = Calendar.current.component(.year, from: Date()) - age
        }
        return d
    }
}
