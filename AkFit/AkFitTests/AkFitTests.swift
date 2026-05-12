import Testing
import Foundation
@testable import AkFit

// MARK: - DaySummary tests

struct DaySummaryTests {

    // MARK: - Remaining values

    @Test func remaining_subtractsConsumedFromTarget() {
        var summary = DaySummary(
            targetCalories: 2000, targetProteinG: 150, targetCarbsG: 200, targetFatG: 60
        )
        summary.consumedCalories = 800
        summary.consumedProteinG = 50
        summary.consumedCarbsG   = 80
        summary.consumedFatG     = 20

        #expect(summary.remainingCalories == 1200)
        #expect(summary.remainingProteinG == 100)
        #expect(summary.remainingCarbsG   == 120)
        #expect(summary.remainingFatG     == 40)
    }

    @Test func remaining_clampedAtZeroWhenOverBudget() {
        var summary = DaySummary(
            targetCalories: 2000, targetProteinG: 150, targetCarbsG: 200, targetFatG: 60
        )
        summary.consumedCalories = 2500
        summary.consumedProteinG = 200
        summary.consumedCarbsG   = 210
        summary.consumedFatG     = 70

        #expect(summary.remainingCalories == 0)
        #expect(summary.remainingProteinG == 0)
        #expect(summary.remainingCarbsG   == 0)
        #expect(summary.remainingFatG     == 0)
    }

    @Test func remaining_exactlyAtTargetIsZero() {
        var summary = DaySummary(
            targetCalories: 2000, targetProteinG: 150, targetCarbsG: 200, targetFatG: 60
        )
        summary.consumedCalories = 2000
        summary.consumedProteinG = 150
        summary.consumedCarbsG   = 200
        summary.consumedFatG     = 60

        #expect(summary.remainingCalories == 0)
        #expect(summary.remainingProteinG == 0)
        #expect(summary.remainingCarbsG   == 0)
        #expect(summary.remainingFatG     == 0)
    }

    // MARK: - Progress fractions

    @Test func calorieProgress_halfConsumedReturnsDotFive() {
        var summary = DaySummary(
            targetCalories: 2000, targetProteinG: 150, targetCarbsG: 200, targetFatG: 60
        )
        summary.consumedCalories = 1000
        #expect(summary.calorieProgress == 0.5)
    }

    @Test func progress_clampedAtOneWhenOverBudget() {
        var summary = DaySummary(
            targetCalories: 2000, targetProteinG: 150, targetCarbsG: 200, targetFatG: 60
        )
        summary.consumedCalories = 3000
        summary.consumedProteinG = 300

        #expect(summary.calorieProgress == 1.0)
        #expect(summary.proteinProgress == 1.0)
    }

    @Test func progress_zeroWhenTargetIsZero() {
        let summary = DaySummary(
            targetCalories: 0, targetProteinG: 0, targetCarbsG: 0, targetFatG: 0
        )
        #expect(summary.calorieProgress == 0.0)
        #expect(summary.proteinProgress == 0.0)
        #expect(summary.carbsProgress   == 0.0)
        #expect(summary.fatProgress     == 0.0)
    }

    // MARK: - Factory

    @Test func from_goal_mapsTargetsCorrectly() {
        let goal = UserGoal(
            id: UUID(), userId: UUID(),
            goalType: .fatLoss,
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: 1900, dailyProtein: 155,
            dailyCarbs: 210, dailyFat: 55,
            createdAt: Date(), updatedAt: Date()
        )
        let summary = DaySummary.from(goal: goal)

        #expect(summary.targetCalories   == 1900)
        #expect(summary.targetProteinG   == 155)
        #expect(summary.targetCarbsG     == 210)
        #expect(summary.targetFatG       == 55)
        #expect(summary.consumedCalories == 0)
        #expect(summary.remainingCalories == 1900)
    }

    // MARK: - Factory with logs

    private static func makeGoal(
        calories: Int = 2100, protein: Int = 165, carbs: Int = 220, fat: Int = 65
    ) -> UserGoal {
        UserGoal(
            id: UUID(), userId: UUID(),
            goalType: .fatLoss,
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: calories, dailyProtein: protein,
            dailyCarbs: carbs, dailyFat: fat,
            createdAt: Date(), updatedAt: Date()
        )
    }

    private static func makeLog(
        calories: Int, proteinG: Double, carbsG: Double, fatG: Double
    ) -> FoodLog {
        let uid = UUID()
        return FoodLog(
            id: UUID(), userId: uid,
            foodName: "test", servingLabel: "100g", quantity: 1.0,
            calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG,
            mealSlot: .snack, loggedAt: Date(), createdAt: Date()
        )
    }

    @Test func from_goalLogs_emptyLogsLeavesConsumedZero() {
        let summary = DaySummary.from(goal: Self.makeGoal(), logs: [])
        #expect(summary.consumedCalories == 0)
        #expect(summary.consumedProteinG == 0)
        #expect(summary.consumedCarbsG   == 0)
        #expect(summary.consumedFatG     == 0)
        #expect(summary.remainingCalories == 2100)
    }

    @Test func from_goalLogs_sumsPreScaledMacros() {
        // Two logs: totals = 402 kcal, P 51.9g, C 29.0g, F 7.2g.
        // Macro grams round half-to-even per Double.rounded(): 52, 29, 7.
        let logs = [
            Self.makeLog(calories: 154, proteinG: 5.4,  carbsG: 26.0, fatG: 2.8),
            Self.makeLog(calories: 248, proteinG: 46.5, carbsG: 3.0,  fatG: 4.4),
        ]
        let summary = DaySummary.from(goal: Self.makeGoal(), logs: logs)

        #expect(summary.consumedCalories == 402)
        #expect(summary.consumedProteinG == 52)   // 5.4 → 5 + 46.5 → 47   (round half-to-even)
        #expect(summary.consumedCarbsG   == 29)   // 26 + 3
        #expect(summary.consumedFatG     == 7)    // 2.8 → 3 + 4.4 → 4
        #expect(summary.remainingCalories == 1698)
    }

    @Test func from_goalLogs_matchesManualLoop() {
        // Behavior-preservation check: the new factory must produce the same
        // result as the hand-rolled loop the views used before.
        let goal = Self.makeGoal()
        let logs = [
            Self.makeLog(calories: 154, proteinG: 5.4,  carbsG: 26.0, fatG: 2.8),
            Self.makeLog(calories: 248, proteinG: 46.5, carbsG: 0.0,  fatG: 5.4),
            Self.makeLog(calories: 120, proteinG: 24.0, carbsG: 3.0,  fatG: 1.5),
        ]

        var manual = DaySummary.from(goal: goal)
        for log in logs {
            manual.consumedCalories += log.calories
            manual.consumedProteinG += Int(log.proteinG.rounded())
            manual.consumedCarbsG   += Int(log.carbsG.rounded())
            manual.consumedFatG     += Int(log.fatG.rounded())
        }

        let helper = DaySummary.from(goal: goal, logs: logs)

        #expect(helper.consumedCalories == manual.consumedCalories)
        #expect(helper.consumedProteinG == manual.consumedProteinG)
        #expect(helper.consumedCarbsG   == manual.consumedCarbsG)
        #expect(helper.consumedFatG     == manual.consumedFatG)
    }

    // MARK: - addConsumed

    @Test func addConsumed_addsPreScaledMacros() {
        var summary = DaySummary.from(goal: Self.makeGoal())
        summary.addConsumed(calories: 300, proteinG: 31.0, carbsG: 0.0, fatG: 3.6)

        #expect(summary.consumedCalories == 300)
        #expect(summary.consumedProteinG == 31)
        #expect(summary.consumedCarbsG   == 0)
        #expect(summary.consumedFatG     == 4)   // 3.6 → 4
    }

    @Test func addConsumed_stacksOnExistingConsumption() {
        // Verifies the FoodDetail "After this log" projection pattern:
        // start from today's logs, then layer the not-yet-logged food on top.
        let logs = [Self.makeLog(calories: 200, proteinG: 20.0, carbsG: 10.0, fatG: 5.0)]
        var summary = DaySummary.from(goal: Self.makeGoal(), logs: logs)
        summary.addConsumed(calories: 165, proteinG: 31.0, carbsG: 0.0, fatG: 3.6)

        #expect(summary.consumedCalories == 365)
        #expect(summary.consumedProteinG == 51)
        #expect(summary.consumedCarbsG   == 10)
        #expect(summary.consumedFatG     == 9)   // 5 + 4
    }
}

// MARK: - UserProfile computed property tests

struct UserProfileTests {

    private static func makeProfile(birthdate: String?) -> UserProfile {
        UserProfile(
            id: UUID(), displayName: nil,
            heightCm: nil, weightKg: nil,
            birthdate: birthdate,
            createdAt: Date(), updatedAt: Date()
        )
    }

    @Test func birthYear_parsesFromValidBirthdate() {
        let profile = Self.makeProfile(birthdate: "1992-06-15")
        #expect(profile.birthYear == 1992)
    }

    @Test func birthYear_nilWhenBirthdateIsNil() {
        let profile = Self.makeProfile(birthdate: nil)
        #expect(profile.birthYear == nil)
    }

    @Test func birthYear_nilWhenBirthdateTooShort() {
        let profile = Self.makeProfile(birthdate: "199")
        #expect(profile.birthYear == nil)
    }

    @Test func birthYear_nilWhenYearPortionIsNotNumeric() {
        let profile = Self.makeProfile(birthdate: "XXXX-01-01")
        #expect(profile.birthYear == nil)
    }

    @Test func birthYear_parsesLeadingFourDigits() {
        // Verifies the prefix(4) approach works for a valid date
        let profile = Self.makeProfile(birthdate: "2000-12-31")
        #expect(profile.birthYear == 2000)
    }
}
