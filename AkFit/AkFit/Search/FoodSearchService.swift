import Foundation

/// Abstraction over the food search data source.
///
/// Live implementation: `HybridFoodSearchService` — Supabase `generic_foods`
/// for common items, with `OpenFoodFactsService` as a fallback for branded
/// or packaged products. Wired in `SearchView`.
protocol FoodSearchService: Sendable {
    func search(query: String) async -> [FoodItem]
}
