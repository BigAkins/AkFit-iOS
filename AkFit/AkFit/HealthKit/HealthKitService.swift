import Foundation
import HealthKit
import OSLog

private let hkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AkFit",
    category: "HealthKit"
)

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

    /// `false` in the Simulator where HealthKit authorization is not safe to present.
    /// Note: HealthKit IS available on iPad since iPadOS 17.
    var isAvailable: Bool { !Self.isSimulator && HKHealthStore.isHealthDataAvailable() }

    /// `true` while `requestAuthorization()` is in flight. Prevents concurrent
    /// calls — multiple authorization requests can crash `HKHealthStore` on
    /// iPadOS 26.
    private(set) var isRequesting: Bool = false

    // MARK: - Private

    /// Lazily initialized so `HKHealthStore()` is never created until HealthKit
    /// is confirmed available. Eager initialization caused a crash on iOS 26 when
    /// the store was created before the window scene was fully active.
    /// `@ObservationIgnored` prevents the `@Observable` macro from wrapping this
    /// infrastructure property with observation hooks (it has no observable surface).
    @ObservationIgnored private lazy var store = HKHealthStore()

    /// All writable sample types AkFit requests authorization to save.
    ///
    /// Important: `HKCorrelationType(.food)` is intentionally excluded here.
    /// HealthKit rejects authorization requests that try to share `.food`,
    /// which causes `_throwIfAuthorizationDisallowedForSharing:types:` to abort
    /// the request before the system sheet can complete.
    private var shareTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        types.insert(HKQuantityType(.bodyMass))
        types.insert(HKQuantityType(.dietaryEnergyConsumed))
        types.insert(HKQuantityType(.dietaryProtein))
        types.insert(HKQuantityType(.dietaryCarbohydrates))
        types.insert(HKQuantityType(.dietaryFatTotal))
        return types
    }

    /// AkFit doesn't read any Health data; authorization is write-only.
    private var readTypes: Set<HKObjectType> { [] }

    private static var isSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    private var shareTypeIdentifiers: String {
        shareTypes
            .map(\.identifier)
            .sorted()
            .joined(separator: ", ")
    }

    private var readTypeIdentifiers: String {
        readTypes
            .map(\.identifier)
            .sorted()
            .joined(separator: ", ")
    }

    // MARK: - Authorization

    /// Requests HealthKit write authorization for food nutrition and body mass.
    ///
    /// Presents the system authorization sheet the first time it's called.
    /// On subsequent calls (or after the user has already decided) HealthKit
    /// re-checks silently — no sheet is shown again. Safe to call multiple times.
    ///
    /// Re-entrancy guard prevents concurrent calls — multiple in-flight
    /// authorization requests can crash `HKHealthStore` on iPadOS 26.
    func requestAuthorization() async {
        hkLogger.info(
            "requestAuthorization called — simulator: \(Self.isSimulator, privacy: .public), healthDataAvailable: \(HKHealthStore.isHealthDataAvailable(), privacy: .public)"
        )
        guard isAvailable else {
            hkLogger.info("requestAuthorization skipped — HealthKit unavailable")
            return
        }
        guard !isRequesting else {
            hkLogger.info("requestAuthorization skipped — already in progress")
            return
        }
        isRequesting = true
        defer { isRequesting = false }
        do {
            hkLogger.info("requestAuthorization share types — [\(self.shareTypeIdentifiers, privacy: .public)]")
            hkLogger.info("requestAuthorization read types — [\(self.readTypeIdentifiers, privacy: .public)]")
            hkLogger.info("requestAuthorization — presenting system sheet")
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            refreshStatus()
            hkLogger.info("requestAuthorization succeeded — status: \(String(describing: self.authStatus))")
        } catch {
            let nsError = error as NSError
            hkLogger.error(
                "requestAuthorization failed — domain: \(nsError.domain, privacy: .public) code: \(nsError.code, privacy: .public) message: \(error.localizedDescription, privacy: .public)"
            )
            // Authorization failures are non-fatal; export calls will no-op.
            // Do NOT call refreshStatus() here — if the authorization call itself
            // failed, the store may be in a bad state and querying it could crash.
            // Preserve the prior status so transient presentation / environment
            // failures do not strand the UI in a fake "denied" state.
        }
    }

    /// Reads the current authorization state from HealthKit and updates `authStatus`.
    ///
    /// Call this when `SettingsView` appears so the displayed status reflects any
    /// changes the user made via iPhone Settings → Privacy → Health.
    func checkAuthorization() {
        hkLogger.info(
            "checkAuthorization called — simulator: \(Self.isSimulator, privacy: .public), healthDataAvailable: \(HKHealthStore.isHealthDataAvailable(), privacy: .public)"
        )
        guard isAvailable else {
            hkLogger.info("checkAuthorization skipped — HealthKit unavailable")
            return
        }
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
        guard isAvailable else { return }
        switch store.authorizationStatus(for: HKQuantityType(.bodyMass)) {
        case .sharingAuthorized: authStatus = .authorized
        case .sharingDenied:     authStatus = .denied
        default:                 authStatus = .notDetermined
        }
    }
}
