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

        // Normalize the query the same way the DB search_text column is normalized:
        // remove apostrophes, replace hyphens with spaces, collapse whitespace.
        // Then apply known aliases (e.g. "innout" → "in n out").
        let queryMatch = SearchTextMatcher.queryMatch(for: q)
        let normalized = queryMatch.normalized
        guard !normalized.isEmpty else { return [] }

        let words = queryMatch.words

        do {
            let rows: [GenericFoodRow]

            if words.count <= 1 {
                // Single word: direct substring match via ilike.
                rows = try await SupabaseClientProvider.shared
                    .from("generic_foods")
                    .select()
                    .ilike("search_text", pattern: "%\(normalized)%")
                    .order("food_name")
                    .limit(30)
                    .execute()
                    .value
            } else {
                // Multi-word: query by the longest (most selective) word, then
                // filter client-side so ALL words must be present. This handles
                // non-contiguous queries like "greek van" → "Greek Yogurt, Vanilla"
                // or "chick sand" → "Chick-fil-A Chicken Sandwich".
                let pivot = words.max(by: { $0.count < $1.count }) ?? normalized
                let candidates: [GenericFoodRow] = try await SupabaseClientProvider.shared
                    .from("generic_foods")
                    .select()
                    .ilike("search_text", pattern: "%\(pivot)%")
                    .order("food_name")
                    .limit(100)
                    .execute()
                    .value
                rows = candidates.filter { row in
                    SearchTextMatcher.matchesAllQueryWords(
                        term: row.foodName,
                        queryMatch: queryMatch
                    )
                }
            }

            // Re-rank client-side by match quality so exact/prefix matches surface
            // before weaker substring hits. Dessert/processed items get a penalty
            // so whole foods rank above them for plain queries like "strawberry".
            return rows.map(FoodItem.init).sorted { a, b in
                var sa = SearchTextMatcher.matchScore(name: a.name, queryMatch: queryMatch)
                var sb = SearchTextMatcher.matchScore(name: b.name, queryMatch: queryMatch)
                if queryMatch.isPlainFoodQuery {
                    if SearchTextMatcher.isDessertOrProcessed(SearchTextMatcher.normalizeForSearch(a.name)) { sa += 1 }
                    if SearchTextMatcher.isDessertOrProcessed(SearchTextMatcher.normalizeForSearch(b.name)) { sb += 1 }
                }
                if sa != sb { return sa < sb }
                // Within the same rank, shorter names are simpler/more generic.
                return a.name.count < b.name.count
            }
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

    /// Returns distinct food names and brand names from `generic_foods` for
    /// the type-ahead suggestion pool. Every returned term is guaranteed to
    /// be resolvable by `search(query:)` since it comes from the same table.
    func fetchTypeAheadTerms() async -> [String] {
        do {
            struct TermRow: Decodable {
                let foodName: String
                let brand: String?
                enum CodingKeys: String, CodingKey {
                    case foodName = "food_name"
                    case brand
                }
            }
            let rows: [TermRow] = try await SupabaseClientProvider.shared
                .from("generic_foods")
                .select("food_name, brand")
                .order("food_name")
                .limit(1500)
                .execute()
                .value
            var terms = Set<String>()
            for row in rows {
                terms.insert(row.foodName)
                if let brand = row.brand { terms.insert(brand) }
            }
            return terms.sorted()
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
