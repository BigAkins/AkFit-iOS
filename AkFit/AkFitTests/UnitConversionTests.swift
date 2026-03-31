import Testing
@testable import AkFit

// MARK: - UnitConversionTests
//
// Covers the conversion helpers on `OnboardingData` and verifies
// that the U.S.-unit → metric → MacroCalculator pipeline produces
// correct, internally-consistent results.

struct UnitConversionTests {

    // MARK: - cm → feet + inches

    @Test func cmToFeetInches_5ft7in() {
        let (ft, ins) = OnboardingData.cmToFeetInches(170.18)
        #expect(ft  == 5)
        #expect(ins == 7)
    }

    @Test func cmToFeetInches_exactSixFoot() {
        // 6'0" = 72 in × 2.54 = 182.88 cm exactly
        let (ft, ins) = OnboardingData.cmToFeetInches(182.88)
        #expect(ft  == 6)
        #expect(ins == 0)
    }

    @Test func cmToFeetInches_roundTrip() {
        // For every integral inch count in the picker range (4'0"–7'11"),
        // converting to centimetres and back must recover the original value.
        for totalIn in 48...95 {
            let cm = Double(totalIn) * 2.54
            let (ft, ins) = OnboardingData.cmToFeetInches(cm)
            let recovered = ft * 12 + ins
            #expect(recovered == totalIn, "Round-trip failed for \(totalIn) inches")
        }
    }

    // MARK: - kg → lbs

    @Test func kgToLbs_75kg() {
        // 75 × 2.20462 = 165.3465 → rounds to 165
        #expect(OnboardingData.kgToLbs(75) == 165)
    }

    @Test func kgToLbs_82kg() {
        // 82 × 2.20462 = 180.779 → rounds to 181
        #expect(OnboardingData.kgToLbs(82) == 181)
    }

    @Test func kgToLbs_100kg() {
        // 100 × 2.20462 = 220.462 → rounds to 220
        #expect(OnboardingData.kgToLbs(100) == 220)
    }

    @Test func kgToLbs_roundTrip() {
        // For a selection of common pound values, the round-trip
        // lbs → kg → lbs must recover the original value (±0 due to
        // deliberate rounding in kgToLbs).
        let samples = [100, 120, 140, 150, 165, 180, 200, 220]
        for lbs in samples {
            let kg       = Double(lbs) / 2.20462
            let recovered = OnboardingData.kgToLbs(kg)
            #expect(recovered == lbs, "Round-trip failed for \(lbs) lbs")
        }
    }

    // MARK: - OnboardingData computed metric properties

    @Test func heightCmDerivedCorrectly() {
        let data = OnboardingData()
        data.heightFeet   = 5
        data.heightInches = 7
        // 67 in × 2.54 = 170.18 cm
        let expected = Double(67) * 2.54
        #expect(abs(data.heightCm - expected) < 0.001)
    }

    @Test func weightKgDerivedCorrectly() {
        let data = OnboardingData()
        data.weightLbs = 165
        let expected = Double(165) / 2.20462
        #expect(abs(data.weightKg - expected) < 0.001)
    }

    @Test func defaultsAreReasonable() {
        // Default 5′ 7″ / 165 lbs should map to ~170 cm / ~75 kg.
        let data = OnboardingData()
        #expect(data.heightFeet   == 5)
        #expect(data.heightInches == 7)
        #expect(data.weightLbs    == 165)
        #expect(abs(data.heightCm - 170) < 1.0)
        #expect(abs(data.weightKg -  75) < 1.0)
    }

    // MARK: - from(goal:profile:) pre-population

    @Test func fromGoal_convertsMetricToUS() {
        let goal = UserGoal(
            id: UUID(), userId: UUID(),
            goalType: .fatLoss,
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: 2100, dailyProtein: 165,
            dailyCarbs: 220, dailyFat: 65,
            createdAt: .now, updatedAt: .now
        )
        let profile = UserProfile(
            id: UUID(), displayName: nil,
            heightCm: 182.88, weightKg: 82,
            birthdate: nil, createdAt: .now, updatedAt: .now
        )
        let data = OnboardingData.from(goal: goal, profile: profile)

        // 182.88 cm → 6′ 0″
        #expect(data.heightFeet   == 6)
        #expect(data.heightInches == 0)

        // 82 kg → 181 lbs
        #expect(data.weightLbs == 181)
    }

    // MARK: - Full pipeline: US input → MacroCalculator

    // Male, 5′ 7″, 165 lbs, moderately active, fat loss moderate, age 30.
    //
    // Internal metric values: heightCm ≈ 170.18, weightKg ≈ 74.84
    // BMR  ≈ (10 × 74.84) + (6.25 × 170.18) − (5 × 30) + 5
    //       = 748.4 + 1063.6 − 150 + 5 = 1667.0
    // TDEE ≈ 1667.0 × 1.55 = 2583.9
    // Target = 2583.9 − 500 = 2083.9 → 2084 kcal
    // Protein ≈ 74.84 × 2.20462 = 165 g  (≈ 1 g/lb bodyweight)
    @Test func macroCalculatorViaPipeline_male5ft7_165lbs_fatLoss() {
        let data = OnboardingData()
        data.sex           = .male
        data.birthYear     = Calendar.current.component(.year, from: Date()) - 30
        data.heightFeet    = 5
        data.heightInches  = 7
        data.weightLbs     = 165
        data.goalType      = .fatLoss
        data.activityLevel = .moderate
        data.pace          = .moderate

        guard let input = data.calculatorInput else {
            Issue.record("calculatorInput unexpectedly nil when all fields are set")
            return
        }
        let out = MacroCalculator.calculate(input)

        // Protein: 1 g per lb of bodyweight → 165 g ± 2 (rounding)
        #expect(abs(out.proteinG - 165) <= 2)
        // Calories must be above safety floor and below an unrealistic ceiling
        #expect(out.calories >= 1_200)
        #expect(out.calories <= 3_500)
        // Macro sum must be within 4 kcal of the calorie total (existing test contract)
        let macroSum = out.proteinG * 4 + out.carbsG * 4 + out.fatG * 9
        #expect(abs(macroSum - out.calories) <= 4)
    }

    // Verify that feeding US-derived inputs matches feeding equivalent
    // metric inputs directly — i.e. conversion introduces no bias.
    @Test func pipelineMatchesDirectMetricInput() {
        let usData = OnboardingData()
        usData.sex           = .male
        usData.birthYear     = Calendar.current.component(.year, from: Date()) - 28
        usData.heightFeet    = 5
        usData.heightInches  = 9   // 69 in = 175.26 cm
        usData.weightLbs     = 176  // 176 / 2.20462 ≈ 79.83 kg ≈ 80 kg
        usData.goalType      = .fatLoss
        usData.activityLevel = .moderate
        usData.pace          = .moderate

        let directInput = MacroCalculator.Input(
            sex:           .male,
            weightKg:      80,
            heightCm:      175.26,
            age:           28,
            activityLevel: .moderate,
            goalType:      .fatLoss,
            pace:          .moderate
        )

        guard let pipelineInput = usData.calculatorInput else {
            Issue.record("calculatorInput unexpectedly nil")
            return
        }
        let pipelineOut = MacroCalculator.calculate(pipelineInput)
        let directOut   = MacroCalculator.calculate(directInput)

        // Calorie targets should be within 10 kcal of each other
        // (small delta from conversion rounding; both inputs are ~80 kg / 175 cm).
        #expect(abs(pipelineOut.calories - directOut.calories) <= 10)
        #expect(abs(pipelineOut.proteinG - directOut.proteinG) <= 2)
    }
}
