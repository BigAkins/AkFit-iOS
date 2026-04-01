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
