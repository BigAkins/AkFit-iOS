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
/// Live implementation: `OpenFoodFactsService`. The protocol exists so the
/// scanner UI is decoupled from any single data source — a different backend
/// can be swapped in by replacing the instance held in `BarcodeScannerView`.
protocol BarcodeLookupService {
    func lookup(barcode: String) async -> BarcodeLookupResult
}
