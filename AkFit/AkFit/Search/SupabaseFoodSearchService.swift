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
        // This lets "chick fil a", "in n out", "mcdonalds" match branded names.
        let normalized = Self.normalizeForSearch(q)
        guard !normalized.isEmpty else { return [] }

        let words = normalized.split(separator: " ").map(String.init)

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
                let stemmedWords = words.map { Self.stemWord($0) }
                rows = candidates.filter { row in
                    let n = Self.normalizeForSearch(row.foodName)
                    let nStemmed = Self.stemmedForm(n)
                    return words.allSatisfy { w in n.contains(w) } ||
                           stemmedWords.allSatisfy { sw in nStemmed.contains(sw) }
                }
            }

            // Re-rank client-side by match quality so exact/prefix matches surface
            // before weaker substring hits. Dessert/processed items get a penalty
            // so whole foods rank above them for plain queries like "strawberry".
            let isPlainFoodQuery = words.count <= 2 && words.allSatisfy { $0.allSatisfy(\.isLetter) }
            return rows.map(FoodItem.init).sorted { a, b in
                var sa = Self.matchScore(name: a.name, query: normalized)
                var sb = Self.matchScore(name: b.name, query: normalized)
                if isPlainFoodQuery {
                    if Self.isDessertOrProcessed(Self.normalizeForSearch(a.name)) { sa += 1 }
                    if Self.isDessertOrProcessed(Self.normalizeForSearch(b.name)) { sb += 1 }
                }
                if sa != sb { return sa < sb }
                // Within the same rank, shorter names are simpler/more generic.
                return a.name.count < b.name.count
            }
        } catch {
            return []
        }
    }

    /// Normalizes text for search comparison: lowercased, apostrophes removed,
    /// hyphens/commas/parentheses replaced with spaces, whitespace collapsed.
    /// Mirrors the Postgres `search_text` column transform.
    ///
    /// Internal access so `SearchView` can use the same normalization for
    /// type-ahead suggestion matching.
    static func normalizeForSearch(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")   // right single quote (iOS keyboard)
            .replacingOccurrences(of: "\u{2018}", with: "")   // left single quote
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Reduces a word to a rough stem by stripping common English plural
    /// suffixes. Not a full Porter stemmer — just enough to map
    /// "strawberries" ↔ "strawberry", "blueberries" ↔ "blueberry", etc.
    static func stemWord(_ word: String) -> String {
        let w = word.lowercased()
        guard w.count > 3 else { return w }
        // -ies → -y  (strawberries → strawberry)
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        // -ches, -shes, -xes, -zes, -ses → drop -es
        if w.hasSuffix("es") {
            let stem = String(w.dropLast(2))
            if stem.hasSuffix("ch") || stem.hasSuffix("sh") ||
               stem.hasSuffix("x") || stem.hasSuffix("z") || stem.hasSuffix("s") {
                return stem
            }
        }
        // trailing -s (but not -ss) → drop -s
        if w.hasSuffix("s") && !w.hasSuffix("ss") {
            return String(w.dropLast(1))
        }
        return w
    }

    /// Stems every word in a normalized string for comparison.
    static func stemmedForm(_ text: String) -> String {
        text.split(separator: " ").map { stemWord(String($0)) }.joined(separator: " ")
    }

    /// Levenshtein edit distance between two strings. Used for typo tolerance
    /// in type-ahead suggestions. O(n*m) but only called on short food names.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j-1] + 1, prev[j-1] + cost)
            }
            prev = curr
        }
        return prev[n]
    }

    /// Scores how closely `name` matches `query` (both already normalized).
    /// Lower = better match. Supports stem-aware comparison so "strawberry"
    /// matches "strawberries" at full quality, and applies a category penalty
    /// for desserts/processed items when the query is a plain food word.
    ///
    /// Single-word query:
    ///   0 – exact match or stem-exact   ("egg" → "egg", "strawberry" → "strawberries")
    ///   1 – name starts with (or stemmed prefix)
    ///   2 – first word exact/stem-exact
    ///   3 – any word starts with
    ///   4 – substring only
    ///   +1 penalty for dessert/processed names when query looks like a plain food
    ///
    /// Multi-word query:
    ///   0 – exact match
    ///   1 – name starts with full query OR every query word matches a
    ///       name-word prefix and the first word aligns
    ///   2 – every query word matches a name-word prefix
    ///   3 – all words present as substrings (guaranteed by filter)
    static func matchScore(name: String, query q: String) -> Int {
        let n = normalizeForSearch(name)
        if n == q { return 0 }

        let nStemmed = stemmedForm(n)
        let qStemmed = stemmedForm(q)
        if nStemmed == qStemmed { return 0 }

        if n.hasPrefix(q) || nStemmed.hasPrefix(qStemmed) { return 1 }

        let qWords = q.split(separator: " ").map(String.init)
        let nWords = n.split(separator: " ").map(String.init)
        let qStems = qWords.map { stemWord($0) }
        let nStems = nWords.map { stemWord($0) }

        if qWords.count <= 1 {
            let qStem = qStems[0]
            if nWords.first == q || nStems.first == qStem    { return 2 }
            if nWords.contains(where: { $0.hasPrefix(q) })   { return 3 }
            if nStems.contains(where: { $0.hasPrefix(qStem) }) { return 3 }
            return 4
        }

        // Multi-word: check if every query word is a prefix of some name word
        // (with stem-aware fallback).
        let allWordPrefixes = qWords.indices.allSatisfy { i in
            nWords.contains(where: { $0.hasPrefix(qWords[i]) }) ||
            nStems.contains(where: { $0.hasPrefix(qStems[i]) })
        }
        if allWordPrefixes {
            if let fq = qWords.first, let fn = nWords.first,
               fn.hasPrefix(fq) || stemWord(fn).hasPrefix(stemWord(fq)) {
                return 1
            }
            return 2
        }
        return 3
    }

    /// Words that indicate a dessert or processed item. When the user's query
    /// is a plain food word (e.g. "strawberry") these results should rank below
    /// the whole-food match.
    private static let dessertKeywords: Set<String> = [
        "milkshake", "shake", "ice cream", "smoothie", "cake", "pie",
        "cookie", "brownie", "muffin", "donut", "pastry", "candy",
        "frosting", "sundae", "parfait",
    ]

    /// Returns `true` when a normalized food name looks like a dessert or
    /// processed item — used to add a ranking penalty for plain food queries.
    static func isDessertOrProcessed(_ normalizedName: String) -> Bool {
        dessertKeywords.contains(where: { normalizedName.contains($0) })
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
