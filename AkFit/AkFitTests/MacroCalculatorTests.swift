import Testing
@testable import AkFit

struct MacroCalculatorTests {

    // MARK: - Known-value test
    //
    // Male, 30 y, 175 cm, 80 kg, moderately active, fat loss moderate.
    // BMR  = (10×80) + (6.25×175) − (5×30) + 5  = 800 + 1093.75 − 150 + 5 = 1748.75
    // TDEE = 1748.75 × 1.55 = 2710.56
    // Target = 2710.56 − 500 = 2210.56  → 2211 kcal
    // Protein = 80 × 2.20462 = 176 g
    // Fat     = 2211 × 0.25 / 9 = 61 g
    // Carbs   = (2211 − 176×4 − 61×9) / 4 = (2211 − 704 − 549) / 4 = 958/4 = 240 g

    @Test func knownMaleFatLossModerate() {
        let input = MacroCalculator.Input(
            sex: .male,
            weightKg: 80,
            heightCm: 175,
            age: 30,
            activityLevel: .moderate,
            goalType: .fatLoss,
            pace: .moderate
        )
        let out = MacroCalculator.calculate(input)
        #expect(out.calories == 2211)
        #expect(out.proteinG == 176)
        #expect(out.fatG     == 61)
        #expect(out.carbsG   == 240)
    }

    // MARK: - Female maintenance
    //
    // Female, 25 y, 160 cm, 60 kg, sedentary, maintenance.
    // BMR  = (10×60) + (6.25×160) − (5×25) − 161 = 600 + 1000 − 125 − 161 = 1314
    // TDEE = 1314 × 1.2 = 1576.8  → 1577 kcal
    // Target = 1577 (no adjustment)
    // Protein = 60 × 2.20462 = 132 g
    // Fat     = 1577 × 0.25 / 9 = 44 g
    // Carbs   = (1577 − 132×4 − 44×9) / 4 = (1577 − 528 − 396) / 4 = 653/4 = 163 g

    @Test func knownFemaleMaintenanceSedentary() {
        let input = MacroCalculator.Input(
            sex: .female,
            weightKg: 60,
            heightCm: 160,
            age: 25,
            activityLevel: .sedentary,
            goalType: .maintenance,
            pace: .moderate           // ignored for maintenance
        )
        let out = MacroCalculator.calculate(input)
        #expect(out.calories == 1577)
        #expect(out.proteinG == 132)
        #expect(out.fatG     == 44)
        #expect(out.carbsG   == 163)
    }

    // MARK: - Calorie floor
    //
    // Tiny female, aggressive deficit → should not go below 1200.

    @Test func calorieFloorEnforced() {
        let input = MacroCalculator.Input(
            sex: .female,
            weightKg: 40,
            heightCm: 140,
            age: 60,
            activityLevel: .sedentary,
            goalType: .fatLoss,
            pace: .fast
        )
        let out = MacroCalculator.calculate(input)
        #expect(out.calories >= 1_200)
    }

    // MARK: - Lean bulk surplus

    @Test func leanBulkAddsCalories() {
        let base = MacroCalculator.Input(
            sex: .male,
            weightKg: 75,
            heightCm: 178,
            age: 28,
            activityLevel: .moderate,
            goalType: .maintenance,
            pace: .moderate
        )
        let bulk = MacroCalculator.Input(
            sex: .male,
            weightKg: 75,
            heightCm: 178,
            age: 28,
            activityLevel: .moderate,
            goalType: .leanBulk,
            pace: .fast
        )
        let baseOut = MacroCalculator.calculate(base)
        let bulkOut = MacroCalculator.calculate(bulk)
        #expect(bulkOut.calories > baseOut.calories)
    }

    // MARK: - Pace ordering (fat loss: slow > moderate > fast calories)

    @Test func fatLossPaceOrdering() {
        func make(_ pace: UserGoal.Pace) -> Int {
            MacroCalculator.calculate(MacroCalculator.Input(
                sex: .male, weightKg: 85, heightCm: 180, age: 35,
                activityLevel: .active, goalType: .fatLoss, pace: pace
            )).calories
        }
        #expect(make(.slow) > make(.moderate))
        #expect(make(.moderate) > make(.fast))
    }

    // MARK: - Macros sum to calories (within 4 kcal rounding tolerance)

    @Test func macrosSumToCalories() {
        let input = MacroCalculator.Input(
            sex: .female,
            weightKg: 65,
            heightCm: 168,
            age: 32,
            activityLevel: .light,
            goalType: .fatLoss,
            pace: .slow
        )
        let out = MacroCalculator.calculate(input)
        let sum = out.proteinG * 4 + out.carbsG * 4 + out.fatG * 9
        #expect(abs(sum - out.calories) <= 4)
    }
}
