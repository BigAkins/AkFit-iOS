import Foundation

/// Nutritional totals for a single day: targets, consumed, and derived remaining values.
///
/// Built from the user's active `UserGoal`. The `consumed*` fields start at zero and
/// will be populated from food-log entries once logging is implemented — no structural
/// change to this type is needed at that point.
struct DaySummary {

    // MARK: - Targets (from active goal)

    let targetCalories: Int
    let targetProteinG: Int
    let targetCarbsG:   Int
    let targetFatG:     Int

    // MARK: - Consumed (from today's food log entries)

    var consumedCalories: Int = 0
    var consumedProteinG: Int = 0
    var consumedCarbsG:   Int = 0
    var consumedFatG:     Int = 0

    // MARK: - Remaining (clamped at zero — cannot go negative)

    var remainingCalories: Int { max(0, targetCalories - consumedCalories) }
    var remainingProteinG: Int { max(0, targetProteinG - consumedProteinG) }
    var remainingCarbsG:   Int { max(0, targetCarbsG   - consumedCarbsG)   }
    var remainingFatG:     Int { max(0, targetFatG     - consumedFatG)     }

    // MARK: - Progress fractions (0.0 – 1.0, clamped)

    var calorieProgress: Double { fraction(consumed: consumedCalories, of: targetCalories) }
    var proteinProgress: Double { fraction(consumed: consumedProteinG, of: targetProteinG) }
    var carbsProgress:   Double { fraction(consumed: consumedCarbsG,   of: targetCarbsG)   }
    var fatProgress:     Double { fraction(consumed: consumedFatG,     of: targetFatG)     }

    // MARK: - Factory

    static func from(goal: UserGoal) -> DaySummary {
        DaySummary(
            targetCalories: goal.dailyCalories,
            targetProteinG: goal.dailyProtein,
            targetCarbsG:   goal.dailyCarbs,
            targetFatG:     goal.dailyFat
        )
    }

    // MARK: - Private

    private func fraction(consumed: Int, of target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(consumed) / Double(target))
    }
}
