import Foundation
import Supabase

/// Owns all in-session food log state and the read/write operations.
///
/// Injected into the SwiftUI environment from `AkFitApp`. Multiple views share
/// this single instance — no extra network round-trips needed after mutations.
///
/// ## Guest mode
/// When `guestStore.isActive` is `true`, all operations read from and write to
/// `GuestDataStore` (UserDefaults) instead of Supabase. The in-memory derived
/// lists (`todayLogs`, `recentFoods`, `weekLogs`) are populated the same way
/// in both modes so views need no conditional logic.
///
/// ## Data lifecycle (authenticated path)
/// 1. `DashboardView` calls `refreshToday(userId:)` via `.task` on first appear.
/// 2. `SearchView` calls `refreshRecents(userId:)` via `.task` on first appear.
/// 3. `ProgressTabView` calls `refreshWeek(userId:)` via `.task` on first appear.
/// 4. `FoodDetailView` calls `insert(food:quantity:for:)` on "Log food" tap.
/// 5. On successful insert, all three derived lists update in memory immediately.
@Observable
final class FoodLogStore {

    // MARK: - State

    private(set) var todayLogs:      [FoodLog] = []
    private(set) var recentFoods:    [FoodLog] = []
    private(set) var weekLogs:       [FoodLog] = []
    private(set) var isRefreshing:   Bool      = false
    private(set) var refreshFailed:  Bool      = false
    private(set) var lastLoggedEntry: FoodLog? = nil

    // MARK: - Dependencies

    private let guestStore: GuestDataStore?
    private let authManager: AuthManager?

    private var isGuest: Bool { guestStore?.isActive == true }

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` and
    /// `AuthManager` from `AkFitApp` so authenticated writes can pre-flight
    /// their session via `AuthManager.requireAuthenticatedUserIDForWrite()`.
    ///
    /// Also used as the preview initializer: omit both and pass seed arrays
    /// to populate state without a network call.
    init(
        guestStore:      GuestDataStore? = nil,
        authManager:     AuthManager?    = nil,
        previewLogs:     [FoodLog]       = [],
        previewRecents:  [FoodLog]       = [],
        previewWeekLogs: [FoodLog]       = []
    ) {
        self.guestStore  = guestStore
        self.authManager = authManager
        self.todayLogs   = previewLogs
        self.recentFoods = previewRecents
        self.weekLogs    = previewWeekLogs
    }

    // MARK: - Last-used quantity

    func lastQuantity(for food: FoodItem) -> Double? {
        recentFoods
            .first { $0.foodName == food.name && $0.servingLabel == food.servingSize }
            .map(\.quantity)
    }

    // MARK: - Banner state

    func clearLastLog() {
        lastLoggedEntry = nil
    }

    // MARK: - Reset (called when exiting guest mode)

    /// Clears all in-memory log state. Called by `SettingsView` when the user
    /// exits guest mode so stale guest data doesn't persist in memory.
    func reset() {
        todayLogs       = []
        recentFoods     = []
        weekLogs        = []
        isRefreshing    = false
        refreshFailed   = false
        lastLoggedEntry = nil
    }

    // MARK: - Fetch today

    func refreshToday(userId: UUID) async {
        isRefreshing = true
        refreshFailed = false
        defer { isRefreshing = false }

        // Guest path: filter from in-memory guest store.
        if let gs = guestStore, gs.isActive {
            let (start, end) = todayDates()
            todayLogs = gs.allFoodLogs
                .filter { $0.loggedAt >= start && $0.loggedAt < end }
                .sorted { $0.loggedAt < $1.loggedAt }
            return
        }

        // Authenticated path: Supabase.
        let (startISO, endISO) = todayRange()
        do {
            let logs: [FoodLog] = try await SupabaseClientProvider.shared
                .from("food_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: startISO)
                .lt("logged_at", value: endISO)
                .order("logged_at", ascending: true)
                .execute()
                .value
            todayLogs = logs
        } catch {
            refreshFailed = true
        }
    }

    // MARK: - Fetch recents

    func refreshRecents(userId: UUID) async {
        // Guest path: sort all guest logs newest-first, deduplicate by name.
        if let gs = guestStore, gs.isActive {
            let sorted = gs.allFoodLogs.sorted { $0.loggedAt > $1.loggedAt }
            var seen = Set<String>()
            recentFoods = sorted
                .filter { seen.insert($0.foodName).inserted }
                .prefix(8)
                .map { $0 }
            return
        }

        // Authenticated path: Supabase.
        do {
            let logs: [FoodLog] = try await SupabaseClientProvider.shared
                .from("food_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("logged_at", ascending: false)
                .limit(30)
                .execute()
                .value

            var seen = Set<String>()
            recentFoods = logs
                .filter { seen.insert($0.foodName).inserted }
                .prefix(8)
                .map { $0 }
        } catch {
            // Non-fatal: recentFoods stays empty or stale.
        }
    }

    // MARK: - Fetch week

    /// Fetches food log entries for the past `days` calendar days (today + the
    /// preceding `days - 1` days). Pass a different value to support 7, 30, or
    /// 90-day history ranges in `ProgressTabView`.
    func refreshWeek(userId: UUID, days: Int = 7) async {
        // Guest path: filter from guest store by range start date.
        if let gs = guestStore, gs.isActive {
            let rangeStart = rangeStartDate(days: days)
            weekLogs = gs.allFoodLogs
                .filter { $0.loggedAt >= rangeStart }
                .sorted { $0.loggedAt < $1.loggedAt }
            return
        }

        // Authenticated path: Supabase.
        do {
            let logs: [FoodLog] = try await SupabaseClientProvider.shared
                .from("food_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: rangeStartISO(days: days))
                .order("logged_at", ascending: true)
                .execute()
                .value
            weekLogs = logs
        } catch {
            // Non-fatal: ProgressTabView shows whatever data is available.
        }
    }

    // MARK: - Insert

    func insert(food: FoodItem, quantity: Double, mealSlot: MealSlot, for userId: UUID) async throws {
        let calories = Int((Double(food.calories) * quantity).rounded())
        let proteinG = food.proteinG * quantity
        let carbsG   = food.carbsG   * quantity
        let fatG     = food.fatG     * quantity
        let now      = Date()

        // Guest path: create locally and persist to GuestDataStore.
        if let gs = guestStore, gs.isActive {
            let log = FoodLog(
                id:           UUID(),
                userId:       userId,
                foodName:     food.name,
                servingLabel: food.servingSize,
                quantity:     quantity,
                calories:     calories,
                proteinG:     proteinG,
                carbsG:       carbsG,
                fatG:         fatG,
                mealSlot:     mealSlot,
                loggedAt:     now,
                createdAt:    now
            )
            gs.appendFoodLog(log)
            updateInMemory(with: log)
            return
        }

        // Authenticated path: validate the session (refreshing once if needed)
        // before issuing the write, then persist to Supabase.
        let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
        let payload = FoodLogInsert(
            userId:       validUserId,
            foodName:     food.name,
            servingLabel: food.servingSize,
            quantity:     quantity,
            calories:     calories,
            proteinG:     proteinG,
            carbsG:       carbsG,
            fatG:         fatG,
            mealSlot:     mealSlot,
            loggedAt:     now
        )

        let saved: FoodLog = try await SupabaseClientProvider.shared
            .from("food_logs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        updateInMemory(with: saved)
    }

    /// Appends a saved log to all three in-memory lists and updates `lastLoggedEntry`.
    private func updateInMemory(with log: FoodLog) {
        todayLogs.append(log)
        weekLogs.append(log)

        var seen = Set<String>()
        recentFoods = ([log] + recentFoods)
            .filter { seen.insert($0.foodName).inserted }
            .prefix(8)
            .map { $0 }

        lastLoggedEntry = log
    }

    // MARK: - Delete

    func delete(logId: UUID) async throws {
        // Guest path: remove from GuestDataStore and in-memory lists.
        if let gs = guestStore, gs.isActive {
            gs.deleteFoodLog(id: logId)
            removeFromMemory(logId: logId)
            return
        }

        // Authenticated path: validate the session before issuing the delete.
        // RLS scopes the delete to the owner via `using(auth.uid() = user_id)`.
        _ = try await authManager?.requireAuthenticatedUserIDForWrite()
        try await SupabaseClientProvider.shared
            .from("food_logs")
            .delete()
            .eq("id", value: logId.uuidString)
            .execute()
        removeFromMemory(logId: logId)
    }

    private func removeFromMemory(logId: UUID) {
        todayLogs.removeAll   { $0.id == logId }
        weekLogs.removeAll    { $0.id == logId }
        recentFoods.removeAll { $0.id == logId }
    }

    // MARK: - Date helpers

    /// Returns the start and exclusive end of today in device-local time.
    private func todayDates() -> (start: Date, end: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    /// Returns the start of the `days`-day window (device-local midnight).
    private func rangeStartDate(days: Int) -> Date {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -(days - 1), to: today)!
    }

    /// Returns ISO 8601 strings for today's range (used for Supabase queries).
    private func todayRange() -> (start: String, end: String) {
        let (start, end) = todayDates()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (fmt.string(from: start), fmt.string(from: end))
    }

    /// Returns an ISO 8601 string for the start of the `days`-day window (Supabase queries).
    private func rangeStartISO(days: Int) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: rangeStartDate(days: days))
    }
}

// MARK: - Insert payload (authenticated path)

private struct FoodLogInsert: Encodable {
    let userId:       UUID
    let foodName:     String
    let servingLabel: String
    let quantity:     Double
    let calories:     Int
    let proteinG:     Double
    let carbsG:       Double
    let fatG:         Double
    let mealSlot:     MealSlot
    let loggedAt:     Date

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case foodName     = "food_name"
        case servingLabel = "serving_label"
        case quantity
        case calories
        case proteinG     = "protein_g"
        case carbsG       = "carbs_g"
        case fatG         = "fat_g"
        case mealSlot     = "meal_slot"
        case loggedAt     = "logged_at"
    }
}
