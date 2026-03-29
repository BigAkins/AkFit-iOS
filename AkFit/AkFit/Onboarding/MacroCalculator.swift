import Foundation

/// Pure, stateless macro/calorie target calculator.
///
/// Formula: Mifflin-St Jeor BMR × activity multiplier = TDEE.
/// Deficit/surplus is applied on top of TDEE based on goal + pace.
/// Protein is set first (body-weight based), then fat, then carbs fill the rest.
enum MacroCalculator {

    // MARK: - Input / Output

    struct Input {
        let sex: UserGoal.Sex
        let weightKg: Double
        let heightCm: Double
        let age: Int
        let activityLevel: UserGoal.ActivityLevel
        let goalType: UserGoal.GoalType
        /// Ignored (treated as `.moderate`) when `goalType == .maintenance`.
        let pace: UserGoal.Pace
    }

    struct Output {
        let calories: Int
        let proteinG: Int
        let carbsG: Int
        let fatG: Int
    }

    // MARK: - Public API

    static func calculate(_ input: Input) -> Output {
        let bmr  = mifflinStJeor(input)
        let tdee = bmr * activityMultiplier(input.activityLevel)
        let target = tdee + calorieAdjustment(goalType: input.goalType, pace: input.pace)

        // Floor at 1 200 kcal for safety.
        let calories = max(1_200, Int(target.rounded()))

        // Protein: 1 g per lb of bodyweight (converts kg → lbs).
        let proteinG = Int((input.weightKg * 2.20462).rounded())

        // Fat: ~25 % of calories (9 kcal/g).
        let fatG = Int((Double(calories) * 0.25 / 9).rounded())

        // Carbs: remaining calories (4 kcal/g), floor at 0.
        let proteinCals = proteinG * 4
        let fatCals     = fatG * 9
        let carbCals    = max(0, calories - proteinCals - fatCals)
        let carbsG      = Int((Double(carbCals) / 4).rounded())

        return Output(calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }

    // MARK: - Formula internals

    /// Mifflin-St Jeor BMR (kcal/day).
    private static func mifflinStJeor(_ input: Input) -> Double {
        let base = (10 * input.weightKg)
                 + (6.25 * input.heightCm)
                 - (5 * Double(input.age))
        switch input.sex {
        case .male:   return base + 5
        case .female: return base - 161
        }
    }

    /// Harris-Benedict activity multipliers.
    private static func activityMultiplier(_ level: UserGoal.ActivityLevel) -> Double {
        switch level {
        case .sedentary:  1.2
        case .light:      1.375
        case .moderate:   1.55
        case .active:     1.725
        case .veryActive: 1.9
        }
    }

    /// Calorie delta from TDEE (negative = deficit, positive = surplus).
    private static func calorieAdjustment(goalType: UserGoal.GoalType, pace: UserGoal.Pace) -> Double {
        switch goalType {
        case .maintenance: return 0
        case .fatLoss:
            switch pace {
            case .slow:     return -250
            case .moderate: return -500
            case .fast:     return -750
            }
        case .leanBulk:
            switch pace {
            case .slow:     return 150
            case .moderate: return 300
            case .fast:     return 500
            }
        }
    }
}
