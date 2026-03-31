import Foundation

struct UserGoal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var goalType: GoalType
    var targetWeight: Double?   // user's desired body weight in kg (nullable)
    var targetPace: Pace?       // slow | moderate | fast
    var dailyCalories: Int
    var dailyProtein: Int
    var dailyCarbs: Int
    var dailyFat: Int
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Nested types
    //
    // Sex and ActivityLevel are not stored in `goals` — they live on `profiles`
    // and in onboarding state — but the enums are kept here so that views
    // referencing `UserGoal.Sex` and `UserGoal.ActivityLevel` continue to
    // compile without a namespace change.

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
            case .sedentary:  "Sedentary"
            case .light:      "Lightly Active"
            case .moderate:   "Moderately Active"
            case .active:     "Active"
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
        case userId        = "user_id"
        case goalType      = "goal_type"
        case targetWeight  = "target_weight"
        case targetPace    = "target_pace"
        case dailyCalories = "daily_calories"
        case dailyProtein  = "daily_protein"
        case dailyCarbs    = "daily_carbs"
        case dailyFat      = "daily_fat"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }
}

// MARK: - Custom Decodable

extension UserGoal {
    /// `target_weight` may be stored as a PostgreSQL `numeric` column, which
    /// PostgREST returns as a JSON string.  Decode with a string fallback so
    /// both representations work.  Keeping the init in an extension preserves
    /// the synthesised memberwise initialiser used by previews.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,     forKey: .id)
        userId        = try c.decode(UUID.self,     forKey: .userId)
        goalType      = try c.decode(GoalType.self, forKey: .goalType)
        targetWeight  = Self.decodeFlexDouble(c, key: .targetWeight)
        targetPace    = try c.decodeIfPresent(Pace.self, forKey: .targetPace)
        dailyCalories = try c.decode(Int.self,      forKey: .dailyCalories)
        dailyProtein  = try c.decode(Int.self,      forKey: .dailyProtein)
        dailyCarbs    = try c.decode(Int.self,      forKey: .dailyCarbs)
        dailyFat      = try c.decode(Int.self,      forKey: .dailyFat)
        createdAt     = try c.decode(Date.self,     forKey: .createdAt)
        updatedAt     = try c.decode(Date.self,     forKey: .updatedAt)
    }

    private static func decodeFlexDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double? {
        if let d = try? container.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}
