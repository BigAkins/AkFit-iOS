import Foundation

/// Abstraction over the food search data source.
///
/// The current implementation (`MockFoodSearchService`) filters a local dataset.
/// To connect a real data source — Supabase foods table, USDA FoodData Central,
/// or a third-party nutrition API — implement this protocol and replace the
/// `searchService` instance in `SearchView`.
protocol FoodSearchService: Sendable {
    func search(query: String) async -> [FoodItem]
}

/// Filters `FoodItem.mockDatabase` by name and category.
///
/// Replace with a concrete implementation backed by Supabase or an external
/// API when a real food database is ready. This is the only call site for
/// `FoodItem.mockDatabase`.
struct MockFoodSearchService: FoodSearchService {
    func search(query: String) async -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return FoodItem.mockDatabase.filter { food in
            food.name.lowercased().contains(q) ||
            (food.brandOrCategory?.lowercased().contains(q) ?? false)
        }
    }
}
