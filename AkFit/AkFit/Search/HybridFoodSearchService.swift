import Foundation

/// Two-tier food search: Supabase generic foods first, Open Food Facts fallback.
///
/// **Routing logic:**
/// 1. Always query `generic_foods` in Supabase when query ≥ 2 chars.
///    Returns immediately if at least one generic result is found.
/// 2. If Supabase returns nothing AND query ≥ 3 chars, fall back to
///    Open Food Facts for branded/packaged results.
///
/// This ordering means common foods ("chicken breast", "oats", "egg") resolve
/// instantly with accurate USDA values, while branded searches ("Kind bar",
/// "Chobani") still work via the OFF fallback.
///
/// Task cancellation is checked before each network hop so rapid keystrokes
/// don't pile up in-flight requests.
struct HybridFoodSearchService: FoodSearchService {

    private let generic  = SupabaseFoodSearchService()
    private let packaged = OpenFoodFactsService()

    func search(query: String) async -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }

        // Primary: Supabase generic foods (fast, accurate for common items).
        let genericResults = await generic.search(query: q)
        guard !Task.isCancelled else { return [] }

        if !genericResults.isEmpty {
            return genericResults
        }

        // Fallback: Open Food Facts (branded/packaged only, ≥3 chars to reduce noise).
        guard q.count >= 3 else { return [] }
        return await packaged.search(query: q)
    }
}
