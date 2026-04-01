import Foundation

// MARK: - App user state

/// Top-level routing state for the app.
///
/// `RootView` reads this from `AuthManager` to decide which screen to show.
/// Replaces the previous `isAuthenticated` boolean with an explicit three-way
/// state so guest mode can be handled cleanly without touching Supabase.
enum AppUserState: Equatable {
    /// Not signed in and not in guest mode. `RootView` shows `AuthView`.
    case signedOut
    /// Using the app locally as a guest. No Supabase session exists.
    /// All data is stored in `GuestDataStore` (UserDefaults).
    case guest
    /// Signed in with a Supabase account. Data is stored in the backend.
    case authenticated
}

// MARK: - GuestDataStore

/// Owns all local UserDefaults persistence for guest mode.
///
/// A single instance is created at app launch (`AkFitApp.init`) and injected
/// into `AuthManager`, `FoodLogStore`, and `BodyweightStore` so they all
/// share the same data. **All UserDefaults reads and writes for guest data
/// happen exclusively here.**
///
/// ## What is stored
/// | Key                  | Value                                  |
/// |----------------------|----------------------------------------|
/// | `guest.uuid`         | Stable UUID for this guest session     |
/// | `guest.active`       | Whether guest mode is currently on     |
/// | `guest.goal`         | `UserGoal` set during onboarding       |
/// | `guest.profile`      | `UserProfile` set during onboarding    |
/// | `guest.foodLogs`     | All `[FoodLog]` entries                |
/// | `guest.bodyweightLogs` | All `[BodyweightLog]` entries        |
///
/// ## Security
/// No Supabase credentials, tokens, or session data are stored here.
/// Only nutritional and body-composition data explicitly entered by the user
/// is persisted. All data is isolated to `UserDefaults.standard`.
@Observable
final class GuestDataStore {

    // MARK: - UserDefaults keys

    private enum Keys {
        static let guestId        = "guest.uuid"
        static let isActive       = "guest.active"
        static let goal           = "guest.goal"
        static let profile        = "guest.profile"
        static let foodLogs       = "guest.foodLogs"
        static let bodyweightLogs = "guest.bodyweightLogs"
        static let dailyNotes     = "guest.dailyNotes"
        static let groceryItems   = "guest.groceryItems"
    }

    private let defaults = UserDefaults.standard

    // MARK: - JSON codec
    //
    // Consistent encoder/decoder for all guest data. ISO8601 date strategy
    // matches how the app constructs date strings elsewhere and avoids
    // reference-date ambiguity between encode and decode runs.

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Identity

    /// Stable UUID identifying this guest session.
    /// Created once on first guest launch and persisted indefinitely.
    /// A new UUID is generated only after `clearAll()` is called and
    /// the user re-enters guest mode.
    let guestId: UUID

    // MARK: - Active flag

    /// `true` when the app is in guest mode.
    /// Persisted so guest mode survives app restarts.
    /// Set via `activate()` and cleared via `clearAll()`.
    private(set) var isActive: Bool

    // MARK: - User data

    /// The guest's active goal. `nil` until onboarding completes.
    private(set) var goal: UserGoal?

    /// The guest's profile (body stats + display name). `nil` until onboarding completes.
    private(set) var profile: UserProfile?

    // MARK: - Log data

    /// All food log entries for this guest, across all days.
    /// Filtered by date inside `FoodLogStore` for daily/weekly views.
    private(set) var allFoodLogs: [FoodLog]

    /// All bodyweight entries for this guest, across all days.
    private(set) var allBodyweightLogs: [BodyweightLog]

    /// Daily notes for this guest, keyed by "yyyy-MM-dd" date string.
    private(set) var dailyNotes: [String: String]

    /// All grocery list items for this guest.
    private(set) var allGroceryItems: [GroceryItem]

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Load or create the stable guest UUID.
        if let stored = defaults.string(forKey: Keys.guestId),
           let parsed = UUID(uuidString: stored) {
            self.guestId = parsed
        } else {
            let fresh = UUID()
            defaults.set(fresh.uuidString, forKey: Keys.guestId)
            self.guestId = fresh
        }

        // Load runtime flags and user data.
        self.isActive = defaults.bool(forKey: Keys.isActive)
        self.goal     = Self.load(UserGoal.self,   key: Keys.goal)
        self.profile  = Self.load(UserProfile.self, key: Keys.profile)

        // Load log arrays (default to empty if nothing persisted yet).
        self.allFoodLogs       = Self.load([FoodLog].self,         key: Keys.foodLogs)       ?? []
        self.allBodyweightLogs = Self.load([BodyweightLog].self,   key: Keys.bodyweightLogs) ?? []

        // Load planning data (default to empty).
        self.dailyNotes     = Self.load([String: String].self, key: Keys.dailyNotes)   ?? [:]
        self.allGroceryItems = Self.load([GroceryItem].self,   key: Keys.groceryItems) ?? []
    }

    // MARK: - Activation

    /// Activates guest mode. Sets `isActive = true` and persists the flag.
    func activate() {
        isActive = true
        defaults.set(true, forKey: Keys.isActive)
    }

    // MARK: - User data mutations

    func saveGoal(_ g: UserGoal) {
        goal = g
        persist(g, key: Keys.goal)
    }

    func saveProfile(_ p: UserProfile) {
        profile = p
        persist(p, key: Keys.profile)
    }

    // MARK: - Food log mutations

    func appendFoodLog(_ log: FoodLog) {
        allFoodLogs.append(log)
        persist(allFoodLogs, key: Keys.foodLogs)
    }

    func deleteFoodLog(id: UUID) {
        allFoodLogs.removeAll { $0.id == id }
        persist(allFoodLogs, key: Keys.foodLogs)
    }

    // MARK: - Bodyweight log mutations

    func appendBodyweightLog(_ log: BodyweightLog) {
        allBodyweightLogs.append(log)
        persist(allBodyweightLogs, key: Keys.bodyweightLogs)
    }

    func deleteBodyweightLog(id: UUID) {
        allBodyweightLogs.removeAll { $0.id == id }
        persist(allBodyweightLogs, key: Keys.bodyweightLogs)
    }

    // MARK: - Daily note mutations

    /// Returns the stored note for `date` (a "yyyy-MM-dd" string), or `nil` if none.
    func dailyNote(for date: String) -> String? {
        dailyNotes[date]
    }

    /// Saves or removes the note for `date`. An empty string removes the entry.
    func saveDailyNote(_ content: String, for date: String) {
        if content.isEmpty {
            dailyNotes.removeValue(forKey: date)
        } else {
            dailyNotes[date] = content
        }
        persist(dailyNotes, key: Keys.dailyNotes)
    }

    // MARK: - Grocery item mutations

    func appendGroceryItem(_ item: GroceryItem) {
        allGroceryItems.append(item)
        persist(allGroceryItems, key: Keys.groceryItems)
    }

    /// Replaces the stored item with the same `id`. No-op if not found.
    func updateGroceryItem(_ item: GroceryItem) {
        guard let idx = allGroceryItems.firstIndex(where: { $0.id == item.id }) else { return }
        allGroceryItems[idx] = item
        persist(allGroceryItems, key: Keys.groceryItems)
    }

    func deleteGroceryItem(id: UUID) {
        allGroceryItems.removeAll { $0.id == id }
        persist(allGroceryItems, key: Keys.groceryItems)
    }

    /// Removes all grocery items whose `isChecked` is `true`.
    func clearCheckedGroceryItems() {
        allGroceryItems.removeAll(where: \.isChecked)
        persist(allGroceryItems, key: Keys.groceryItems)
    }

    // MARK: - Clear all guest data

    /// Destroys all persisted guest data and deactivates guest mode.
    ///
    /// Called by `AuthManager.exitGuestMode()` after the user confirms the
    /// destructive action. Clears both UserDefaults and in-memory state.
    ///
    /// A new `guestId` will be generated on the next call to `activate()`.
    func clearAll() {
        isActive          = false
        goal              = nil
        profile           = nil
        allFoodLogs       = []
        allBodyweightLogs = []
        dailyNotes        = [:]
        allGroceryItems   = []

        for key in [Keys.isActive, Keys.goal, Keys.profile,
                    Keys.foodLogs, Keys.bodyweightLogs, Keys.guestId,
                    Keys.dailyNotes, Keys.groceryItems] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private helpers

    private func persist<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? Self.encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
