import Foundation
import Supabase

/// Searches the `generic_foods` table in Supabase for common/generic foods.
///
/// Uses an `ilike '%query%'` filter, which Postgres accelerates via the
/// trigram GIN index added in migration `20260329000003_generic_foods`.
///
/// **Used by:** `HybridFoodSearchService` as the primary search path before
/// falling back to Open Food Facts for branded/packaged items.
struct SupabaseFoodSearchService: FoodSearchService {

    func search(query: String) async -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2, !Task.isCancelled else { return [] }

        do {
            let rows: [GenericFoodRow] = try await SupabaseClientProvider.shared
                .from("generic_foods")
                .select()
                .ilike("food_name", pattern: "%\(q)%")
                .order("food_name")
                .limit(30)
                .execute()
                .value
            return rows.map(FoodItem.init)
        } catch {
            return []
        }
    }
}

// MARK: - Row model

/// Decodable representation of a `generic_foods` row.
private struct GenericFoodRow: Decodable {
    let id:             UUID
    let foodName:       String
    let servingLabel:   String
    let servingWeightG: Double?
    let calories:       Int
    let proteinG:       Double
    let carbsG:         Double
    let fatG:           Double

    enum CodingKeys: String, CodingKey {
        case id
        case foodName       = "food_name"
        case servingLabel   = "serving_label"
        case servingWeightG = "serving_weight_g"
        case calories
        case proteinG       = "protein_g"
        case carbsG         = "carbs_g"
        case fatG           = "fat_g"
    }
}

// MARK: - FoodItem conversion

private extension FoodItem {
    init(_ row: GenericFoodRow) {
        self.init(
            id:              row.id,
            name:            row.foodName,
            brandOrCategory: nil,
            servingSize:     row.servingLabel,
            servingWeightG:  row.servingWeightG ?? 100,
            calories:        row.calories,
            proteinG:        row.proteinG,
            carbsG:          row.carbsG,
            fatG:            row.fatG
        )
    }
}
