import Foundation

/// A single item in the user's grocery list.
///
/// Mirrors the `grocery_items` Supabase table. Stored as a flat ordered list —
/// `sortOrder` preserves insertion order without requiring drag-reorder UI.
///
/// `isChecked` and `name` are `var` so the store can apply optimistic in-memory
/// updates (toggle, future rename) without rebuilding the whole array.
struct GroceryItem: Identifiable, Codable, Sendable {
    let id:         UUID
    let userId:     UUID
    var name:       String
    var isChecked:  Bool
    var sortOrder:  Int
    let createdAt:  Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name
        case isChecked = "is_checked"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}
