import Foundation

struct UserGoal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var goalType: GoalType
    var targetCalories: Int
    var targetProteinG: Int
    var targetCarbsG: Int
    var targetFatG: Int
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var sex: Sex?
    var activityLevel: ActivityLevel?
    var pace: Pace?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Nested types

    enum GoalType: String, Codable, CaseIterable, Sendable {
        case fatLoss     = "fat_loss"
        case maintenance = "maintenance"
        case leanBulk    = "lean_bulk"

        var displayName: String {
            switch self {
            case .fatLoss:     "Fat Loss"
            case .maintenance: "Maintenance"
            case .leanBulk:    "Lean Bulk"
            }
        }
    }

    enum Sex: String, Codable, Sendable {
        case male, female
    }

    enum ActivityLevel: String, Codable, Sendable {
        case sedentary, light, moderate, active
        case veryActive = "very_active"

        var displayName: String {
            switch self {
            case .sedentary: "Sedentary"
            case .light:     "Lightly Active"
            case .moderate:  "Moderately Active"
            case .active:    "Active"
            case .veryActive: "Very Active"
            }
        }
    }

    enum Pace: String, Codable, Sendable {
        case slow, moderate, fast

        var displayName: String {
            switch self {
            case .slow:     "Slow (0.5 lb/week)"
            case .moderate: "Moderate (1 lb/week)"
            case .fast:     "Fast (1.5 lb/week)"
            }
        }
    }

    // MARK: - Coding keys

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case goalType        = "goal_type"
        case targetCalories  = "target_calories"
        case targetProteinG  = "target_protein_g"
        case targetCarbsG    = "target_carbs_g"
        case targetFatG      = "target_fat_g"
        case heightCm        = "height_cm"
        case weightKg        = "weight_kg"
        case age
        case sex
        case activityLevel   = "activity_level"
        case pace
        case isActive        = "is_active"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
    }
}
