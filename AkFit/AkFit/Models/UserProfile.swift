import Foundation

struct UserProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String?
    /// Height in centimetres. Stored in `profiles.height_cm`.
    var heightCm: Double?
    /// Body weight in kilograms. Stored in `profiles.weight_kg`.
    var weightKg: Double?
    /// Date of birth as an ISO-8601 date string ("YYYY-MM-DD").
    /// PostgREST returns PostgreSQL `date` columns as plain date strings, not
    /// timestamps, so this is stored as `String?` to avoid decoder mismatches.
    var birthdate: String?
    /// Biological sex — used by MacroCalculator (Mifflin-St Jeor BMR constant).
    /// Stored in `profiles.sex` as "male" | "female".
    var sex: UserGoal.Sex?
    /// Lifestyle activity level — used by MacroCalculator (TDEE multiplier).
    /// Stored in `profiles.activity_level`.
    var activityLevel: UserGoal.ActivityLevel?
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Derived

    /// Birth year extracted from `birthdate` (e.g. "1990-01-01" → 1990).
    var birthYear: Int? {
        guard let birthdate, birthdate.count >= 4 else { return nil }
        return Int(birthdate.prefix(4))
    }

    /// Exact age in whole years, derived from the full "YYYY-MM-DD" `birthdate`.
    ///
    /// Uses `Calendar.dateComponents` so the result accounts for whether the
    /// birthday has already passed this year — e.g. born June 15 1992, today
    /// March 31 2026 → 33, not 34.
    var age: Int? {
        guard let birthdate else { return nil }
        let parts = birthdate.split(separator: "-")
        guard parts.count == 3,
              let year  = Int(parts[0]),
              let month = Int(parts[1]),
              let day   = Int(parts[2]) else { return nil }
        var comps  = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let birthDate = Calendar.current.date(from: comps) else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    // MARK: - Coding keys

    enum CodingKeys: String, CodingKey {
        case id
        case displayName   = "display_name"
        case heightCm      = "height_cm"
        case weightKg      = "weight_kg"
        case birthdate
        case sex
        case activityLevel = "activity_level"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }
}

// MARK: - Custom Decodable

extension UserProfile {
    /// `height_cm` and `weight_kg` may be stored as PostgreSQL `numeric` columns
    /// that PostgREST serialises as JSON strings.  Decode with a string fallback.
    /// Keeping the init in an extension preserves the synthesised memberwise
    /// initialiser used by previews.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,    forKey: .id)
        displayName   = try c.decodeIfPresent(String.self,               forKey: .displayName)
        heightCm      = Self.decodeFlexDouble(c, key: .heightCm)
        weightKg      = Self.decodeFlexDouble(c, key: .weightKg)
        birthdate     = try c.decodeIfPresent(String.self,               forKey: .birthdate)
        sex           = try c.decodeIfPresent(UserGoal.Sex.self,          forKey: .sex)
        activityLevel = try c.decodeIfPresent(UserGoal.ActivityLevel.self, forKey: .activityLevel)
        createdAt     = try c.decode(Date.self,    forKey: .createdAt)
        updatedAt     = try c.decode(Date.self,    forKey: .updatedAt)
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
