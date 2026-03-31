import Foundation

// MARK: - BodyweightLog model

/// A single persisted bodyweight entry, mirroring the `bodyweight_logs` Supabase table.
///
/// Weights are stored in kilograms for internal consistency with `UserProfile.weightKg`
/// and `OnboardingData.weightKg`. The `weightLbs` computed property converts to
/// pounds for display — the app is US-first but storage stays metric.
struct BodyweightLog: Identifiable, Codable, Sendable {
    let id:        UUID
    let userId:    UUID
    /// Canonical storage unit. Always > 0 (enforced by DB CHECK constraint).
    let weightKg:  Double
    /// When the bodyweight was recorded (device-local time, stored as UTC in the DB).
    let loggedAt:  Date
    let createdAt: Date

    /// Convenience display value in pounds.
    var weightLbs: Double { weightKg * 2.20462 }

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case weightKg  = "weight_kg"
        case loggedAt  = "logged_at"
        case createdAt = "created_at"
    }
}
