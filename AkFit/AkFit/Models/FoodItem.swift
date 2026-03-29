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

// MARK: - Mock dataset
//
// Practical foods with USDA-aligned macro values, covering the most
// commonly tracked items for body-composition goals.
//
// To replace: implement `FoodSearchService` against Supabase or an external
// nutrition API and delete this extension. `MockFoodSearchService` is the
// only call site.

extension FoodItem {
    static let mockDatabase: [FoodItem] = [
        FoodItem(id: UUID(), name: "Chicken Breast, cooked",
                 brandOrCategory: "Poultry",    servingSize: "100g",          servingWeightG: 100,
                 calories: 165, proteinG: 31,   carbsG: 0,    fatG: 3.6),
        FoodItem(id: UUID(), name: "Egg, whole",
                 brandOrCategory: "Dairy & Eggs", servingSize: "1 large (50g)", servingWeightG: 50,
                 calories: 72,  proteinG: 6.3,  carbsG: 0.4,  fatG: 5.0),
        FoodItem(id: UUID(), name: "Greek Yogurt, plain",
                 brandOrCategory: "Dairy & Eggs", servingSize: "100g",          servingWeightG: 100,
                 calories: 59,  proteinG: 10,   carbsG: 3.6,  fatG: 0.4),
        FoodItem(id: UUID(), name: "Oats, rolled",
                 brandOrCategory: "Grains",      servingSize: "40g (½ cup)",   servingWeightG: 40,
                 calories: 154, proteinG: 5.4,  carbsG: 26,   fatG: 2.8),
        FoodItem(id: UUID(), name: "Brown Rice, cooked",
                 brandOrCategory: "Grains",      servingSize: "100g",          servingWeightG: 100,
                 calories: 112, proteinG: 2.6,  carbsG: 23,   fatG: 0.8),
        FoodItem(id: UUID(), name: "White Rice, cooked",
                 brandOrCategory: "Grains",      servingSize: "100g",          servingWeightG: 100,
                 calories: 130, proteinG: 2.7,  carbsG: 28,   fatG: 0.3),
        FoodItem(id: UUID(), name: "Pasta, cooked",
                 brandOrCategory: "Grains",      servingSize: "100g",          servingWeightG: 100,
                 calories: 131, proteinG: 5.0,  carbsG: 25,   fatG: 1.1),
        FoodItem(id: UUID(), name: "Whole Wheat Bread",
                 brandOrCategory: "Grains",      servingSize: "1 slice (28g)", servingWeightG: 28,
                 calories: 69,  proteinG: 3.6,  carbsG: 12,   fatG: 1.0),
        FoodItem(id: UUID(), name: "Salmon, cooked",
                 brandOrCategory: "Seafood",     servingSize: "100g",          servingWeightG: 100,
                 calories: 208, proteinG: 28,   carbsG: 0,    fatG: 10),
        FoodItem(id: UUID(), name: "Tuna, canned in water",
                 brandOrCategory: "Seafood",     servingSize: "100g",          servingWeightG: 100,
                 calories: 109, proteinG: 25,   carbsG: 0,    fatG: 0.5),
        FoodItem(id: UUID(), name: "Ground Beef, 90% lean",
                 brandOrCategory: "Beef",        servingSize: "100g",          servingWeightG: 100,
                 calories: 176, proteinG: 20,   carbsG: 0,    fatG: 10),
        FoodItem(id: UUID(), name: "Turkey Breast, sliced",
                 brandOrCategory: "Poultry",     servingSize: "2 oz (56g)",    servingWeightG: 56,
                 calories: 59,  proteinG: 12,   carbsG: 0.5,  fatG: 0.7),
        FoodItem(id: UUID(), name: "Cottage Cheese",
                 brandOrCategory: "Dairy & Eggs", servingSize: "100g",          servingWeightG: 100,
                 calories: 98,  proteinG: 11,   carbsG: 3.4,  fatG: 4.3),
        FoodItem(id: UUID(), name: "Cheddar Cheese",
                 brandOrCategory: "Dairy & Eggs", servingSize: "1 oz (28g)",    servingWeightG: 28,
                 calories: 113, proteinG: 7.0,  carbsG: 0.4,  fatG: 9.3),
        FoodItem(id: UUID(), name: "Milk, whole",
                 brandOrCategory: "Dairy & Eggs", servingSize: "1 cup (244ml)", servingWeightG: 244,
                 calories: 149, proteinG: 8.0,  carbsG: 12,   fatG: 8.0),
        FoodItem(id: UUID(), name: "Whey Protein",
                 brandOrCategory: "Supplements",  servingSize: "1 scoop (30g)", servingWeightG: 30,
                 calories: 120, proteinG: 24,   carbsG: 3.0,  fatG: 1.5),
        FoodItem(id: UUID(), name: "Peanut Butter",
                 brandOrCategory: "Nuts & Seeds", servingSize: "2 tbsp (32g)", servingWeightG: 32,
                 calories: 191, proteinG: 7.0,  carbsG: 7.0,  fatG: 16),
        FoodItem(id: UUID(), name: "Almonds",
                 brandOrCategory: "Nuts & Seeds", servingSize: "1 oz (28g)",   servingWeightG: 28,
                 calories: 164, proteinG: 6.0,  carbsG: 6.0,  fatG: 14),
        FoodItem(id: UUID(), name: "Avocado",
                 brandOrCategory: "Fruit",        servingSize: "½ medium (75g)", servingWeightG: 75,
                 calories: 120, proteinG: 1.5,  carbsG: 6.4,  fatG: 11),
        FoodItem(id: UUID(), name: "Banana",
                 brandOrCategory: "Fruit",        servingSize: "1 medium (118g)", servingWeightG: 118,
                 calories: 105, proteinG: 1.3,  carbsG: 27,   fatG: 0.4),
        FoodItem(id: UUID(), name: "Apple",
                 brandOrCategory: "Fruit",        servingSize: "1 medium (182g)", servingWeightG: 182,
                 calories: 95,  proteinG: 0.5,  carbsG: 25,   fatG: 0.3),
        FoodItem(id: UUID(), name: "Orange",
                 brandOrCategory: "Fruit",        servingSize: "1 medium (131g)", servingWeightG: 131,
                 calories: 62,  proteinG: 1.2,  carbsG: 15,   fatG: 0.2),
        FoodItem(id: UUID(), name: "Sweet Potato, baked",
                 brandOrCategory: "Vegetables",   servingSize: "100g",          servingWeightG: 100,
                 calories: 90,  proteinG: 2.0,  carbsG: 21,   fatG: 0.1),
        FoodItem(id: UUID(), name: "Broccoli",
                 brandOrCategory: "Vegetables",   servingSize: "100g",          servingWeightG: 100,
                 calories: 34,  proteinG: 2.8,  carbsG: 7.0,  fatG: 0.4),
        FoodItem(id: UUID(), name: "Lentils, cooked",
                 brandOrCategory: "Legumes",      servingSize: "100g",          servingWeightG: 100,
                 calories: 116, proteinG: 9.0,  carbsG: 20,   fatG: 0.4),
    ]
}
