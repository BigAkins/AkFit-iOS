import Foundation

/// The four fixed meal slots a food log entry can belong to.
///
/// Stored as a raw `String` in Supabase (`meal_slot` column, CHECK-constrained).
/// Text over Postgres enum so the set of values can be extended in a future
/// migration without an `ALTER TYPE`.
enum MealSlot: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch:     "Lunch"
        case .dinner:    "Dinner"
        case .snack:     "Snack"
        }
    }

    /// Canonical display order for dashboard grouping.
    static let orderedCases: [MealSlot] = [.breakfast, .lunch, .dinner, .snack]

    /// Infers a sensible default slot from the hour of day.
    ///
    ///  5–10 → breakfast
    /// 11–14 → lunch
    /// 15–20 → dinner
    /// all other hours → snack
    ///
    /// Used to pre-select the picker in `FoodDetailView` and to assign a slot
    /// for quick-log actions that bypass the detail screen.
    static func inferred(from date: Date = Date()) -> MealSlot {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default:      return .snack
        }
    }
}
