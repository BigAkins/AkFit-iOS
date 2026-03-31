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

    // MARK: - Custom decoding

    /// PostgREST serializes PostgreSQL `numeric` columns as JSON strings
    /// (e.g. `"175.0"`) rather than JSON numbers, to preserve precision.
    /// The default `JSONDecoder` cannot decode a string into `Double`, so
    /// `height_cm` and `weight_kg` need a string-fallback path.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,           forKey: .id)
        userId         = try c.decode(UUID.self,           forKey: .userId)
        goalType       = try c.decode(GoalType.self,       forKey: .goalType)
        targetCalories = try c.decode(Int.self,            forKey: .targetCalories)
        targetProteinG = try c.decode(Int.self,            forKey: .targetProteinG)
        targetCarbsG   = try c.decode(Int.self,            forKey: .targetCarbsG)
        targetFatG     = try c.decode(Int.self,            forKey: .targetFatG)
        heightCm       = Self.decodeFlexDouble(c, key: .heightCm)
        weightKg       = Self.decodeFlexDouble(c, key: .weightKg)
        age            = try c.decodeIfPresent(Int.self,           forKey: .age)
        sex            = try c.decodeIfPresent(Sex.self,           forKey: .sex)
        activityLevel  = try c.decodeIfPresent(ActivityLevel.self, forKey: .activityLevel)
        pace           = try c.decodeIfPresent(Pace.self,          forKey: .pace)
        isActive       = try c.decode(Bool.self,           forKey: .isActive)
        createdAt      = try c.decode(Date.self,           forKey: .createdAt)
        updatedAt      = try c.decode(Date.self,           forKey: .updatedAt)
    }

    /// Decodes a `numeric` column that PostgREST may return as a JSON string
    /// ("175.0") or a JSON number (175.0). Returns `nil` when the key is absent.
    private static func decodeFlexDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double? {
        if let d = try? container.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}
