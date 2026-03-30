import Foundation

// MARK: - Result type

/// The result of a barcode lookup. Either a matched `FoodItem` or an indication
/// that the barcode is not in the available database.
enum BarcodeLookupResult {
    case found(FoodItem)
    case notFound
}

// MARK: - Protocol

/// Resolves a barcode string (EAN-13, UPC-A, etc.) to a `FoodItem`.
///
/// Kept as a protocol so the mock can be swapped for a real implementation
/// backed by Open Food Facts, USDA FoodData Central, or a Supabase-hosted
/// product catalogue without touching the scanner UI.
protocol BarcodeLookupService {
    func lookup(barcode: String) async -> BarcodeLookupResult
}

// MARK: - Mock implementation

/// Hardcoded barcode → `FoodItem` mapping for common packaged foods.
///
/// Used during development. Replace with a real network call when a product
/// database is integrated. The barcode values below are real EAN-13/UPC-A
/// codes for recognisable products that exercise the happy path in testing.
final class MockBarcodeLookupService: BarcodeLookupService {

    func lookup(barcode: String) async -> BarcodeLookupResult {
        // Simulate a brief network-like delay so loading state is visible.
        try? await Task.sleep(for: .milliseconds(500))
        guard let item = Self.database[barcode] else { return .notFound }
        return .found(item)
    }

    // MARK: - Mock database

    private static let database: [String: FoodItem] = [

        // Chobani Non-Fat Plain Greek Yogurt (5.3 oz)
        "818290013620": FoodItem(
            id: UUID(), name: "Chobani Plain Greek Yogurt",
            brandOrCategory: "Chobani",
            servingSize: "1 container (150g)", servingWeightG: 150,
            calories: 80, proteinG: 14, carbsG: 6, fatG: 0
        ),

        // KIND Protein Dark Chocolate Nut bar
        "602652175577": FoodItem(
            id: UUID(), name: "KIND Protein Bar",
            brandOrCategory: "KIND",
            servingSize: "1 bar (50g)", servingWeightG: 50,
            calories: 250, proteinG: 12, carbsG: 17, fatG: 17
        ),

        // Quaker Old Fashioned Oats
        "030000056158": FoodItem(
            id: UUID(), name: "Quaker Old Fashioned Oats",
            brandOrCategory: "Quaker",
            servingSize: "½ cup dry (40g)", servingWeightG: 40,
            calories: 150, proteinG: 5, carbsG: 27, fatG: 3
        ),

        // Skippy Creamy Peanut Butter
        "037600127066": FoodItem(
            id: UUID(), name: "Skippy Creamy Peanut Butter",
            brandOrCategory: "Skippy",
            servingSize: "2 tbsp (32g)", servingWeightG: 32,
            calories: 190, proteinG: 7, carbsG: 7, fatG: 16
        ),

        // Optimum Nutrition Gold Standard 100% Whey
        "748927023046": FoodItem(
            id: UUID(), name: "Gold Standard Whey Protein",
            brandOrCategory: "Optimum Nutrition",
            servingSize: "1 scoop (31g)", servingWeightG: 31,
            calories: 120, proteinG: 24, carbsG: 3, fatG: 1
        ),

        // RXBAR Chocolate Sea Salt
        "856190005015": FoodItem(
            id: UUID(), name: "RXBAR Chocolate Sea Salt",
            brandOrCategory: "RXBAR",
            servingSize: "1 bar (52g)", servingWeightG: 52,
            calories: 210, proteinG: 12, carbsG: 23, fatG: 9
        ),

        // Fairlife Core Power Elite Chocolate (42g protein)
        "611269992419": FoodItem(
            id: UUID(), name: "Core Power Elite Protein Shake",
            brandOrCategory: "Fairlife",
            servingSize: "1 bottle (414ml)", servingWeightG: 414,
            calories: 230, proteinG: 42, carbsG: 12, fatG: 3.5
        ),
    ]
}
