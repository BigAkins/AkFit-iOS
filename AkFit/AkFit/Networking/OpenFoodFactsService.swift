import Foundation

/// Resolves barcodes and searches for packaged foods using the
/// [Open Food Facts](https://world.openfoodfacts.org) public API.
///
/// Conforms to both `FoodSearchService` and `BarcodeLookupService` so a single
/// shared instance can be injected wherever either protocol is needed.
///
/// **No API key required.** Open Food Facts is a non-profit open-data project.
///
/// **Data quality notes:**
/// - Coverage is best for barcoded packaged goods sold in the US and Europe.
/// - Nutritional values are crowd-sourced and may contain errors or gaps.
///   The normalization layer handles missing fields gracefully (see `toFoodItem`).
/// - Searching for generic foods ("chicken breast", "2 eggs") will surface branded
///   variants rather than USDA-style generic entries. The in-app "Common foods"
///   list (backed by `FoodItem.mockDatabase`) fills this gap for the prompt / empty
///   state in `SearchView` — no change needed there.
///
/// **To replace this service:** conform a new type to `FoodSearchService` and/or
/// `BarcodeLookupService`, then swap the instance in `SearchView` and
/// `BarcodeScannerView`. No other files need to change.
struct OpenFoodFactsService: FoodSearchService, BarcodeLookupService {

    // MARK: - Shared URLSession

    /// One session for all OFF requests. Configured with a short timeout and a
    /// descriptive User-Agent per OFF's API guidelines.
    /// Static so it is shared across all service instances without allocating
    /// a new session per call site.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 20
        // OFF asks apps to identify themselves in the User-Agent.
        config.httpAdditionalHeaders = [
            "User-Agent": "AkFit/1.0 (iOS; calorie and macro tracker)"
        ]
        return URLSession(configuration: config)
    }()

    private static let decoder = JSONDecoder()

    /// Minimal field projection sent to OFF — keeps payloads small.
    private static let fields =
        "product_name,product_name_en,brands,serving_size,serving_quantity,nutriments"

    // MARK: - FoodSearchService

    /// Returns up to 15 matching packaged foods from Open Food Facts.
    ///
    /// Returns an empty array on network errors or cancellation — `SearchView`
    /// shows its existing "no results" state in that case.
    /// Requires at least 2 characters to avoid noise from single-character queries.
    ///
    /// Results pass through two quality gates:
    /// 1. `toFoodItem` rejects products with missing/unusable names, non-Latin
    ///    scripts, clearly invalid nutrition, and ugly formatting.
    /// 2. `isSearchQuality` rejects zero-nutrition ghost entries and items with
    ///    implausibly high calories (> 1 500 per serving).
    func search(query: String) async -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2, !Task.isCancelled else { return [] }

        do {
            let products = try await fetchSearch(query: q)
            // Sort so products with an explicit English name are processed first.
            // This means the prefix cap favours English-language results even when
            // OFF returns a mixed-language set.
            let sorted = products.sorted { a, b in
                let aHasEn = a.productNameEn.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
                let bHasEn = b.productNameEn.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
                return aHasEn && !bHasEn
            }
            return sorted
                .compactMap(Self.toFoodItem)
                .filter(Self.isSearchQuality)
                .prefix(15)
                .map { $0 }
        } catch {
            return []
        }
    }

    /// Additional quality filter applied only to search results (not barcode
    /// lookups, which are verified products with a known barcode).
    ///
    /// Catches zero-nutrition ghost entries and implausibly high-calorie items
    /// that survive `toFoodItem`'s general validation.
    private static func isSearchQuality(_ item: FoodItem) -> Bool {
        // Reject zero-nutrition entries (water, empty stubs)
        let hasAnyNutrition = item.calories > 0
            || item.proteinG > 0
            || item.carbsG > 0
            || item.fatG > 0
        guard hasAnyNutrition else { return false }

        // Reject items with non-zero calories but all macros zero — almost
        // certainly a data-entry error where only the energy field was filled.
        if item.calories > 0 && item.proteinG == 0 && item.carbsG == 0 && item.fatG == 0 {
            return false
        }

        // 1 500 kcal per serving is the practical upper bound for search results.
        // Barcode lookups keep the original 5 000 cap via `toFoodItem`.
        guard item.calories <= 1_500 else { return false }

        return true
    }

    // MARK: - BarcodeLookupService

    /// Looks up a barcode on Open Food Facts.
    /// Returns `.notFound` if the barcode is absent from OFF, data is unusable,
    /// or a network error occurs.
    func lookup(barcode: String) async -> BarcodeLookupResult {
        do {
            guard let product = try await fetchProduct(barcode: barcode),
                  let item = Self.toFoodItem(product)
            else { return .notFound }
            return .found(item)
        } catch {
            return .notFound
        }
    }

    // MARK: - Network requests

    /// `GET /api/v2/product/{barcode}` — single product by barcode.
    /// Returns `nil` when OFF reports `status: 0` (product not in database).
    private func fetchProduct(barcode: String) async throws -> OFFProduct? {
        guard var components = URLComponents(
            string: "https://world.openfoodfacts.org/api/v2/product/\(barcode)"
        ) else { return nil }
        components.queryItems = [URLQueryItem(name: "fields", value: Self.fields)]
        guard let url = components.url else { return nil }

        let (data, _) = try await Self.session.data(from: url)
        let response  = try Self.decoder.decode(OFFProductResponse.self, from: data)
        // status 1 = found, 0 = not found
        guard response.status == 1 else { return nil }
        return response.product
    }

    /// `GET /cgi/search.pl` — keyword search returning up to 20 products.
    private func fetchSearch(query: String) async throws -> [OFFProduct] {
        guard var components = URLComponents(
            string: "https://world.openfoodfacts.org/cgi/search.pl"
        ) else { return [] }
        components.queryItems = [
            URLQueryItem(name: "action",       value: "process"),
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "json",         value: "1"),
            URLQueryItem(name: "page_size",    value: "20"),
            URLQueryItem(name: "fields",       value: Self.fields),
            URLQueryItem(name: "lc",           value: "en"),
        ]
        guard let url = components.url else { return [] }

        let (data, _) = try await Self.session.data(from: url)
        let response  = try Self.decoder.decode(OFFSearchResponse.self, from: data)
        return response.products ?? []
    }

    // MARK: - Normalization

    /// Maps an OFF product record to the app's `FoodItem` model.
    /// Returns `nil` when the product name is missing, nutritional data
    /// is clearly invalid (e.g. calories > 5 000 per serving), or the product
    /// name is primarily in a non-Latin script (Cyrillic, Arabic, CJK, etc.).
    ///
    /// **Serving strategy:**
    /// 1. If `serving_quantity` is present and > 0, use `_serving` nutriment values.
    ///    Fall back to pro-rating `_100g` values when `_serving` keys are absent.
    /// 2. Otherwise use `_100g` values and report a 100 g serving.
    ///
    /// **Energy fallback:**
    /// When calorie data is entirely absent, estimates via Atwater factors
    /// (protein × 4 + carbs × 4 + fat × 9).
    private static func toFoodItem(_ product: OFFProduct) -> FoodItem? {
        // Require a non-empty name — prefer the explicit English variant when available.
        let name: String
        if let en = product.productNameEn,
           !en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = en.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let generic = product.productName,
                  !generic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = generic.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return nil
        }

        // Reject products whose names are primarily non-Latin script (e.g. Cyrillic,
        // Arabic, CJK, Japanese). Keeps U.S.-relevant results without blocking
        // accented Western-language names (French, Spanish, German, etc.).
        guard Self.isLatinScript(name) else { return nil }

        // Reject very short or excessively long names.
        guard name.count >= 3, name.count <= 100 else { return nil }

        let n          = product.nutriments
        let useServing = (product.servingQuantity ?? 0) > 0

        let protein:        Double
        let carbs:          Double
        let fat:            Double
        let calories:       Int
        let servingWeightG: Double
        let servingSize:    String

        if useServing, let sw = product.servingQuantity {
            // Scale per-100 g values to serving weight when per-serving keys are absent.
            let scale = sw / 100

            protein = max(0, n?.proteinsServing
                ?? (n?.proteins100g ?? 0) * scale)
            carbs   = max(0, n?.carbohydratesServing
                ?? (n?.carbohydrates100g ?? 0) * scale)
            fat     = max(0, n?.fatServing
                ?? (n?.fat100g ?? 0) * scale)

            let explicitKcal = n?.energyKcalServing
                ?? n?.energyKcal100g.map { $0 * scale }
            let kcal = explicitKcal ?? (protein * 4 + carbs * 4 + fat * 9)
            calories = max(0, Int(kcal.rounded()))

            servingWeightG = sw

            // Use the declared serving_size label when non-empty; synthesise otherwise.
            if let declared = product.servingSize,
               !declared.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                servingSize = declared.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                servingSize = "1 serving (\(Int(sw.rounded()))g)"
            }

        } else {
            // No serving data — present per-100 g values.
            protein = max(0, n?.proteins100g ?? 0)
            carbs   = max(0, n?.carbohydrates100g ?? 0)
            fat     = max(0, n?.fat100g ?? 0)

            let explicitKcal = n?.energyKcal100g
            let kcal = explicitKcal ?? (protein * 4 + carbs * 4 + fat * 9)
            calories = max(0, Int(kcal.rounded()))

            servingWeightG = 100
            servingSize    = "100g"
        }

        // Hard cap: > 5 000 kcal per serving is almost certainly a data-entry error.
        guard calories <= 5_000 else { return nil }

        // Brand: first entry of OFF's comma-separated brands string.
        var brand: String? = nil
        if let brands = product.brands,
           let first  = brands.split(separator: ",").first {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { brand = trimmed }
        }

        // Clean up name and serving label for display quality.
        let cleanedName    = Self.cleanProductName(name, brand: brand)
        let cleanedServing = Self.cleanServingLabel(servingSize)
        guard cleanedName.count >= 3 else { return nil }

        return FoodItem(
            id:              UUID(),
            name:            cleanedName,
            brandOrCategory: brand,
            servingSize:     cleanedServing,
            servingWeightG:  servingWeightG,
            calories:        calories,
            proteinG:        protein,
            carbsG:          carbs,
            fatG:            fat
        )
    }

    // MARK: - Name & serving cleanup

    /// Cleans a product name for display:
    /// - Strips leading/trailing quotes and stray punctuation.
    /// - Removes doubled brand prefix ("Coca-Cola Coca-Cola Classic" → "Coca-Cola Classic").
    private static func cleanProductName(_ name: String, brand: String?) -> String {
        var result = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // "Brand Brand Foo" or "Brand - Brand Foo" → "Brand Foo"
        if let b = brand, !b.isEmpty {
            for sep in [" ", " - "] {
                let doubled = b + sep + b
                if result.lowercased().hasPrefix(doubled.lowercased()) {
                    result = String(result.dropFirst(b.count + sep.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        return result
    }

    /// Cleans a serving label for display:
    /// - Rounds ugly floating-point metric values ("354.881999mL" → "355mL").
    /// - Truncates overly long labels.
    private static func cleanServingLabel(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return s }

        // Round metric values with 3+ decimal places: "354.881999mL" → "355mL"
        // Keeps values with 1–2 decimal places intact ("12.5g" stays).
        if let regex = try? NSRegularExpression(
            pattern: #"(\d+\.\d{3,})\s*(m[lL]|g|kg|oz)"#
        ) {
            let ns = s as NSString
            if let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
               let numRange = Range(match.range(at: 1), in: s),
               let unitRange = Range(match.range(at: 2), in: s),
               let fullRange = Range(match.range, in: s),
               let value = Double(s[numRange])
            {
                let rounded = Int(value.rounded())
                s.replaceSubrange(fullRange, with: "\(rounded)\(s[unitRange])")
            }
        }

        // Truncate overly long labels to keep rows compact.
        if s.count > 60 {
            s = String(s.prefix(57)) + "…"
        }

        return s
    }

    // MARK: - Helpers

    /// Returns `true` when at least 50 % of `string`'s Unicode scalars fall within
    /// the Latin script blocks (Basic Latin 0000–007F, Latin-1 Supplement 0080–00FF,
    /// Latin Extended-A/B 0100–024F).  Covers English, French, Spanish, German,
    /// Italian, and other Western-alphabet languages while rejecting names primarily
    /// in Cyrillic, Arabic, CJK, Japanese, Korean, or other non-Latin scripts.
    private static func isLatinScript(_ string: String) -> Bool {
        let scalars = string.unicodeScalars
        guard !scalars.isEmpty else { return false }
        let latinCount = scalars.filter { $0.value <= 0x024F }.count
        return Double(latinCount) / Double(scalars.count) >= 0.5
    }
}

// MARK: - OFF response types (file-private)

private struct OFFProductResponse: Decodable {
    /// 1 = found, 0 = not found.
    let status:  Int
    let product: OFFProduct?
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]?
}

/// Minimal projection of an OFF product record.
/// All fields are optional — OFF data completeness varies widely by product.
private struct OFFProduct: Decodable {
    let productName:     String?
    let productNameEn:   String?
    let brands:          String?
    let servingSize:     String?
    /// Weight of one declared serving in grams.
    /// Decoded with a custom init because this field occasionally arrives as a
    /// String ("100") rather than a Number (100) in OFF's JSON.
    let servingQuantity: Double?
    let nutriments:      OFFNutriments?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productName   = try? c.decode(String.self, forKey: .productName)
        productNameEn = try? c.decode(String.self, forKey: .productNameEn)
        brands        = try? c.decode(String.self, forKey: .brands)
        servingSize   = try? c.decode(String.self, forKey: .servingSize)
        nutriments    = try? c.decode(OFFNutriments.self, forKey: .nutriments)

        // Gracefully accept both numeric and string representations.
        if let d = try? c.decode(Double.self, forKey: .servingQuantity) {
            servingQuantity = d
        } else if let s = try? c.decode(String.self, forKey: .servingQuantity),
                  let d = Double(s) {
            servingQuantity = d
        } else {
            servingQuantity = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case productName     = "product_name"
        case productNameEn   = "product_name_en"
        case brands          = "brands"
        case servingSize     = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments      = "nutriments"
    }
}

/// Nutritional values from OFF.
/// `_serving` keys are scoped to the declared serving size; `_100g` keys are per 100 g.
/// All fields use `try?` in the custom init to survive partial or type-mismatched data.
private struct OFFNutriments: Decodable {
    let energyKcal100g:       Double?
    let energyKcalServing:    Double?
    let proteins100g:         Double?
    let proteinsServing:      Double?
    let carbohydrates100g:    Double?
    let carbohydratesServing: Double?
    let fat100g:              Double?
    let fatServing:           Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g       = try? c.decode(Double.self, forKey: .energyKcal100g)
        energyKcalServing    = try? c.decode(Double.self, forKey: .energyKcalServing)
        proteins100g         = try? c.decode(Double.self, forKey: .proteins100g)
        proteinsServing      = try? c.decode(Double.self, forKey: .proteinsServing)
        carbohydrates100g    = try? c.decode(Double.self, forKey: .carbohydrates100g)
        carbohydratesServing = try? c.decode(Double.self, forKey: .carbohydratesServing)
        fat100g              = try? c.decode(Double.self, forKey: .fat100g)
        fatServing           = try? c.decode(Double.self, forKey: .fatServing)
    }

    enum CodingKeys: String, CodingKey {
        case energyKcal100g       = "energy-kcal_100g"
        case energyKcalServing    = "energy-kcal_serving"
        case proteins100g         = "proteins_100g"
        case proteinsServing      = "proteins_serving"
        case carbohydrates100g    = "carbohydrates_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case fat100g              = "fat_100g"
        case fatServing           = "fat_serving"
    }
}
