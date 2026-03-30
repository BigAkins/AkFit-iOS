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

    /// Returns a small, curated set of foods for the empty-state "Suggestions"
    /// section. Values come from `generic_foods` so they are always consistent
    /// with search results.
    ///
    /// One serving per food is returned — the smallest declared serving weight.
    /// Foods appear in `priorityNames` order (protein-first, practical for
    /// body-composition goals). Returns `[]` silently on any error.
    func fetchSuggestions() async -> [FoodItem] {
        let priorityNames: [String] = [
            "Chicken Breast, cooked",
            "Egg, whole",
            "Greek Yogurt, plain nonfat",
            "Oats, rolled (dry)",
            "Whey Protein Powder",
            "Banana",
            "Peanut Butter",
        ]
        do {
            let rows: [GenericFoodRow] = try await SupabaseClientProvider.shared
                .from("generic_foods")
                .select()
                .in("food_name", values: priorityNames)
                .order("food_name")
                .order("serving_weight_g", ascending: true)
                .execute()
                .value
            // Keep only the first (smallest) serving per food name.
            var seen = Set<String>()
            let deduped = rows.filter { seen.insert($0.foodName).inserted }
            // Re-order to the desired priority sequence.
            let rank = Dictionary(uniqueKeysWithValues: priorityNames.enumerated().map { ($1, $0) })
            return deduped
                .sorted { (rank[$0.foodName] ?? 99) < (rank[$1.foodName] ?? 99) }
                .map(FoodItem.init)
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
