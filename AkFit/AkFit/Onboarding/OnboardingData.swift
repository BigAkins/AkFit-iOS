import Foundation

// MARK: - OnboardingData

/// Local state container for the onboarding flow.
///
/// Passed through the step views via the environment. Once all required
/// fields are set, `calculatorInput` produces a non-nil `MacroCalculator.Input`
/// that can be fed to `MacroCalculator.calculate(_:)`.
///
/// **Unit policy:**
/// Height and weight are collected and displayed in U.S. customary units
/// (feet + inches, pounds). The metric equivalents `heightCm` and `weightKg`
/// are computed properties used exclusively by `MacroCalculator` and the
/// Supabase persistence layer — callers never need to convert manually.
@Observable
final class OnboardingData {

    // MARK: - Collected fields

    var sex: UserGoal.Sex?
    var birthYear: Int = Calendar.current.component(.year, from: Date()) - 30

    /// Height — feet component (4–7).
    var heightFeet: Int = 5
    /// Height — inches component (0–11).
    var heightInches: Int = 7
    /// Weight in pounds (66–440 covers 30–200 kg).
    var weightLbs: Int = 165

    var goalType: UserGoal.GoalType?
    var activityLevel: UserGoal.ActivityLevel?
    var pace: UserGoal.Pace = .moderate

    // MARK: - Metric conversions (MacroCalculator + persistence)

    /// Height in centimetres, derived from the stored feet + inches values.
    /// Used by `MacroCalculator.Input` and the Supabase insert/update payloads.
    var heightCm: Double {
        Double(heightFeet * 12 + heightInches) * 2.54
    }

    /// Weight in kilograms, derived from the stored pound value.
    /// Used by `MacroCalculator.Input` and the Supabase insert/update payloads.
    var weightKg: Double {
        Double(weightLbs) / 2.20462
    }

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
            sex:           sex,
            weightKg:      weightKg,
            heightCm:      heightCm,
            age:           age,
            activityLevel: activityLevel,
            goalType:      goalType,
            pace:          pace
        )
    }
}

// MARK: - Settings pre-population

extension OnboardingData {
    /// Builds an `OnboardingData` pre-populated from a saved `UserGoal`.
    ///
    /// Used by `EditGoalView` to seed the edit form with the user's current
    /// goal inputs. Converts the stored metric values to U.S. display units.
    static func from(goal: UserGoal) -> OnboardingData {
        let d = OnboardingData()
        d.goalType      = goal.goalType
        d.sex           = goal.sex
        d.activityLevel = goal.activityLevel
        d.pace          = goal.pace ?? .moderate

        if let cm = goal.heightCm {
            let (ft, ins) = cmToFeetInches(cm)
            d.heightFeet   = ft
            d.heightInches = ins
        }
        if let kg = goal.weightKg {
            d.weightLbs = kgToLbs(kg)
        }
        if let age = goal.age {
            d.birthYear = Calendar.current.component(.year, from: Date()) - age
        }
        return d
    }

    // MARK: - Unit conversion helpers

    /// Converts centimetres to (feet, inches). Rounds to the nearest whole inch.
    ///
    /// Examples:
    /// - 170.18 cm → (5, 7)   (5′ 7″)
    /// - 182.88 cm → (6, 0)   (6′ 0″)
    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((cm / 2.54).rounded())
        return (feet: totalInches / 12, inches: totalInches % 12)
    }

    /// Converts kilograms to whole pounds. Rounds to the nearest pound.
    ///
    /// Example: 75 kg → 165 lbs.
    static func kgToLbs(_ kg: Double) -> Int {
        Int((kg * 2.20462).rounded())
    }
}
