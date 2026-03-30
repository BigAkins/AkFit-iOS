import Foundation
import HealthKit

/// One-way export bridge from AkFit to Apple Health.
///
/// **Scope:** write-only. AkFit never reads from HealthKit — this is a pure
/// export layer so logged food and bodyweight entries appear in Health.app's
/// Nutrition and Body Measurements sections.
///
/// **Authorization:** lazily requested from `SettingsView`. Export calls
/// are silently no-ops when Health is unavailable (iPad, Simulator) or
/// when the user hasn't granted write permission — HealthKit export is a
/// convenience, not a critical path.
///
/// **Thread safety:** inherits `@MainActor` from the project default
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). `HKHealthStore` async
/// methods are not `@MainActor`-isolated, so they run off the main actor
/// and resume here on completion — no blocking.
@Observable
final class HealthKitService {

    // MARK: - Authorization status

    enum AuthStatus: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    /// Current write-authorization state for body mass (used as a proxy for all
    /// AkFit HealthKit types). `.notDetermined` until `requestAuthorization()` or
    /// `checkAuthorization()` is called.
    private(set) var authStatus: AuthStatus = .notDetermined

    /// `false` on iPad and in the Simulator where HealthKit is unavailable.
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Private

    private let store = HKHealthStore()

    /// All sample and correlation types AkFit writes to Health.
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        types.insert(HKQuantityType(.bodyMass))
        types.insert(HKQuantityType(.dietaryEnergyConsumed))
        types.insert(HKQuantityType(.dietaryProtein))
        types.insert(HKQuantityType(.dietaryCarbohydrates))
        types.insert(HKQuantityType(.dietaryFatTotal))
        if let food = HKCorrelationType.correlationType(forIdentifier: .food) {
            types.insert(food)
        }
        return types
    }

    // MARK: - Authorization

    /// Requests HealthKit write authorization for food nutrition and body mass.
    ///
    /// Presents the system authorization sheet the first time it's called.
    /// On subsequent calls (or after the user has already decided) HealthKit
    /// re-checks silently — no sheet is shown again. Safe to call multiple times.
    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
        } catch {
            // Authorization failures are non-fatal; export calls will no-op.
        }
        refreshStatus()
    }

    /// Reads the current authorization state from HealthKit and updates `authStatus`.
    ///
    /// Call this when `SettingsView` appears so the displayed status reflects any
    /// changes the user made via iPhone Settings → Privacy → Health.
    func checkAuthorization() {
        guard isAvailable else { return }
        refreshStatus()
    }

    // MARK: - Food export

    /// Exports a food log entry to Health as an `HKCorrelation` of type `.food`,
    /// bundling kcal, protein, carbs, and fat so the entry appears in Health.app's
    /// Nutrition section with the food name as the label.
    ///
    /// Non-throwing — export failures never interrupt the food logging flow.
    func exportFoodLog(_ log: FoodLog) async {
        guard isAvailable else { return }
        guard let foodType = HKCorrelationType.correlationType(forIdentifier: .food) else { return }

        let date        = log.loggedAt
        let energySample = HKQuantitySample(
            type:     HKQuantityType(.dietaryEnergyConsumed),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(log.calories)),
            start: date, end: date
        )
        let proteinSample = HKQuantitySample(
            type:     HKQuantityType(.dietaryProtein),
            quantity: HKQuantity(unit: .gram(), doubleValue: log.proteinG),
            start: date, end: date
        )
        let carbsSample = HKQuantitySample(
            type:     HKQuantityType(.dietaryCarbohydrates),
            quantity: HKQuantity(unit: .gram(), doubleValue: log.carbsG),
            start: date, end: date
        )
        let fatSample = HKQuantitySample(
            type:     HKQuantityType(.dietaryFatTotal),
            quantity: HKQuantity(unit: .gram(), doubleValue: log.fatG),
            start: date, end: date
        )

        let correlation = HKCorrelation(
            type:    foodType,
            start:   date,
            end:     date,
            objects: [energySample, proteinSample, carbsSample, fatSample],
            metadata: [HKMetadataKeyFoodType: log.foodName]
        )

        do {
            try await store.save(correlation)
        } catch {
            // Non-fatal — export is best-effort.
        }
    }

    // MARK: - Bodyweight export

    /// Exports a bodyweight reading to Health as `HKQuantityTypeIdentifier.bodyMass`
    /// (stored in kilograms, displayed in the user's preferred unit by Health.app).
    ///
    /// Non-throwing — export failures never interrupt the weight logging flow.
    func exportBodyweight(weightKg: Double, loggedAt: Date) async {
        guard isAvailable else { return }

        let sample = HKQuantitySample(
            type:     HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg),
            start:    loggedAt,
            end:      loggedAt
        )
        do {
            try await store.save(sample)
        } catch {
            // Non-fatal.
        }
    }

    // MARK: - Private helpers

    private func refreshStatus() {
        switch store.authorizationStatus(for: HKQuantityType(.bodyMass)) {
        case .sharingAuthorized: authStatus = .authorized
        case .sharingDenied:     authStatus = .denied
        default:                 authStatus = .notDetermined
        }
    }
}
