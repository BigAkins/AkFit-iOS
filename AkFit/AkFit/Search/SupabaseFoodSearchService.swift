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
            // Re-rank client-side by match quality so exact/prefix matches surface
            // before weaker substring hits.  E.g. searching "bacon" shows
            // "Bacon, cooked" (prefix → rank 1) before "Turkey Bacon" (word-prefix → rank 3).
            let ql = q.lowercased()
            return rows.map(FoodItem.init).sorted { a, b in
                let sa = Self.matchScore(name: a.name, query: ql)
                let sb = Self.matchScore(name: b.name, query: ql)
                if sa != sb { return sa < sb }
                // Within the same rank, shorter names are simpler/more generic.
                return a.name.count < b.name.count
            }
        } catch {
            return []
        }
    }

    /// Scores how closely `name` matches `query` (both should be lowercased).
    /// Lower = better match.
    ///
    /// 0 – exact match          ("egg" → "egg")
    /// 1 – name starts with     ("bacon" → "Bacon, cooked")
    /// 2 – first word exact     ("egg" → "Egg, whole")
    /// 3 – any word starts with ("bacon" → "Turkey Bacon")
    /// 4 – substring only       ("rice" → "White Rice, cooked")
    private static func matchScore(name: String, query q: String) -> Int {
        let n = name.lowercased()
        if n == q                                                     { return 0 }
        if n.hasPrefix(q)                                             { return 1 }
        let words = n.split(separator: " ").map(String.init)
        if words.first == q                                           { return 2 }
        if words.contains(where: { $0.hasPrefix(q) })                { return 3 }
        return 4
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
    /// Restaurant or brand name (e.g. "McDonald's", "Chipotle").
    /// `nil` for generic USDA foods. Maps to `FoodItem.brandOrCategory`.
    let brand:          String?

    enum CodingKeys: String, CodingKey {
        case id
        case foodName       = "food_name"
        case servingLabel   = "serving_label"
        case servingWeightG = "serving_weight_g"
        case calories
        case proteinG       = "protein_g"
        case carbsG         = "carbs_g"
        case fatG           = "fat_g"
        case brand
    }
}

// MARK: - FoodItem conversion

private extension FoodItem {
    init(_ row: GenericFoodRow) {
        self.init(
            id:              row.id,
            name:            row.foodName,
            brandOrCategory: row.brand,
            servingSize:     row.servingLabel,
            servingWeightG:  row.servingWeightG ?? 100,
            calories:        row.calories,
            proteinG:        row.proteinG,
            carbsG:          row.carbsG,
            fatG:            row.fatG
        )
    }
}
