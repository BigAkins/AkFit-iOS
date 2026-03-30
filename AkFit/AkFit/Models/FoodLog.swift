import Foundation

// MARK: - FoodLog model

/// A single persisted food log entry, mirroring the `food_logs` Supabase table.
///
/// `calories` and macro gram fields are stored **pre-scaled** at log time
/// (food value × quantity) so reading them requires no further multiplication.
struct FoodLog: Identifiable, Codable, Sendable {
    let id:           UUID
    let userId:       UUID
    let foodName:     String
    /// Human-readable serving description from `FoodItem.servingSize`, e.g. "100g".
    let servingLabel: String
    /// Multiplier applied to the base serving at log time. 1.5 = 1.5 servings.
    let quantity:     Double
    /// Pre-scaled calories (food.calories × quantity), rounded to nearest integer.
    let calories:     Int
    /// Pre-scaled protein grams (food.proteinG × quantity).
    let proteinG:     Double
    /// Pre-scaled carbohydrate grams (food.carbsG × quantity).
    let carbsG:       Double
    /// Pre-scaled fat grams (food.fatG × quantity).
    let fatG:         Double
    /// Which meal this entry belongs to. Defaults to `.snack` for rows that
    /// existed before the meal_slot column was added (via DB migration default).
    let mealSlot:     MealSlot
    /// When the food was consumed (device-local time, stored as UTC in the DB).
    let loggedAt:     Date
    let createdAt:    Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case foodName     = "food_name"
        case servingLabel = "serving_label"
        case quantity
        case calories
        case proteinG     = "protein_g"
        case carbsG       = "carbs_g"
        case fatG         = "fat_g"
        case mealSlot     = "meal_slot"
        case loggedAt     = "logged_at"
        case createdAt    = "created_at"
    }
}

// MARK: - Re-log bridge

extension FoodLog {
    /// Reconstructs a `FoodItem` from this log entry so the existing
    /// `FoodDetailView` can be used for quick re-logging.
    ///
    /// Macro values are back-calculated per serving by dividing the stored
    /// pre-scaled values by `quantity` (e.g. `proteinG / quantity` gives
    /// protein per one serving). This is always exact because `quantity > 0`
    /// is enforced by the DB schema.
    ///
    /// `servingWeightG` is set to 0 — gram weight is not stored in `food_logs`.
    /// `FoodDetailView` handles this gracefully by omitting the "· Xg total"
    /// subtitle when `servingWeightG` is 0.
    func asFoodItem() -> FoodItem {
        FoodItem(
            id:              UUID(),
            name:            foodName,
            brandOrCategory: nil,
            servingSize:     servingLabel,
            servingWeightG:  0,
            calories:        Int((Double(calories) / quantity).rounded()),
            proteinG:        proteinG / quantity,
            carbsG:          carbsG   / quantity,
            fatG:            fatG     / quantity
        )
    }
}
