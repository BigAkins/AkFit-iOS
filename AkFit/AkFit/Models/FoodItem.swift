import Foundation

/// A single food entry as returned from search.
///
/// All macro values are per the stated `servingSize`.
/// `servingWeightG` stores the gram equivalent of the serving for future
/// portion scaling (e.g. "What is 1.5× this serving?").
struct FoodItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    /// Brand name or broad category (e.g. "Generic", "Dairy"). Shown as secondary label.
    let brandOrCategory: String?
    /// Human-readable serving description, e.g. "100g" or "1 large (50g)".
    let servingSize: String
    /// Serving weight in grams — the base unit for portion scaling in food detail.
    let servingWeightG: Double
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}
