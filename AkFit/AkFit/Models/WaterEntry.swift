import Foundation

// MARK: - WaterEntry model

/// A single persisted water intake event, mirroring the `water_entries`
/// Supabase table.
///
/// Water is stored in milliliters for backend consistency. UI surfaces can use
/// `amountOz` for US-friendly display.
struct WaterEntry: Identifiable, Codable, Sendable {
    let id:        UUID
    let userId:    UUID
    /// Canonical storage unit. Always 1...5000 (enforced by DB CHECK constraint).
    let amountMl:  Int
    /// When the water was consumed (device-local time, stored as UTC in the DB).
    let loggedAt:  Date
    let createdAt: Date

    /// Convenience display value in US fluid ounces.
    var amountOz: Double { Self.ounces(fromMilliliters: amountMl) }

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case amountMl  = "amount_ml"
        case loggedAt  = "logged_at"
        case createdAt = "created_at"
    }
}

extension WaterEntry {
    static let millilitersPerOunce = 29.5735295625

    static func milliliters(fromOunces ounces: Double) -> Int {
        Int((ounces * millilitersPerOunce).rounded())
    }

    static func ounces(fromMilliliters milliliters: Int) -> Double {
        Double(milliliters) / millilitersPerOunce
    }
}
