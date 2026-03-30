import Foundation

/// A single user-saved favorite food entry, mirroring the `favorite_foods` Supabase table.
///
/// All nutrition values are stored per the stated `servingLabel` — the same
/// convention as `FoodLog`. No quantity scaling is applied here; the user
/// adjusts quantity in `FoodDetailView` when they re-log the food.
///
/// **Source independence:** Values are denormalized at save time so favorites
/// work correctly regardless of whether the food came from Supabase
/// `generic_foods` or Open Food Facts (which has ephemeral UUIDs).
struct FavoriteFood: Identifiable, Codable, Sendable {
    let id:              UUID
    let userId:          UUID
    let foodName:        String
    /// Human-readable serving description from `FoodItem.servingSize`, e.g. "100g".
    let servingLabel:    String
    /// Serving weight in grams. 0 when unknown (same convention as `FoodLog.asFoodItem`).
    let servingWeightG:  Double
    let calories:        Int
    let proteinG:        Double
    let carbsG:          Double
    let fatG:            Double
    /// Brand or category. `nil` for generic/USDA foods.
    let brandOrCategory: String?
    let createdAt:       Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case foodName        = "food_name"
        case servingLabel    = "serving_label"
        case servingWeightG  = "serving_weight_g"
        case calories
        case proteinG        = "protein_g"
        case carbsG          = "carbs_g"
        case fatG            = "fat_g"
        case brandOrCategory = "brand_or_category"
        case createdAt       = "created_at"
    }
}

// MARK: - FoodItem bridge

extension FavoriteFood {
    /// Reconstructs a `FoodItem` so `FoodDetailView` can be used directly
    /// for re-logging from the Favorites list in `SearchView`.
    func asFoodItem() -> FoodItem {
        FoodItem(
            id:              UUID(),
            name:            foodName,
            brandOrCategory: brandOrCategory,
            servingSize:     servingLabel,
            servingWeightG:  servingWeightG,
            calories:        calories,
            proteinG:        proteinG,
            carbsG:          carbsG,
            fatG:            fatG
        )
    }
}
