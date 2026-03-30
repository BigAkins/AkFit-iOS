import Foundation
import Supabase

/// Owns all in-session food log state and the Supabase read/write operations.
///
/// Injected into the SwiftUI environment from `AkFitApp`. Multiple views share
/// this single instance — no extra network round-trips needed after mutations.
///
/// ## Data lifecycle
/// 1. `DashboardView` calls `refreshToday(userId:)` via `.task` on first appear.
/// 2. `SearchView` calls `refreshRecents(userId:)` via `.task` on first appear.
/// 3. `ProgressTabView` calls `refreshWeek(userId:)` via `.task` on first appear.
/// 4. `FoodDetailView` calls `insert(food:quantity:for:)` on "Log food" tap.
/// 5. On successful insert, all three derived lists update in memory immediately.
@Observable
final class FoodLogStore {

    // MARK: - State

    /// All confirmed food log entries for the current calendar day (device local time).
    private(set) var todayLogs: [FoodLog] = []

    /// The most recently logged distinct foods across all days, newest first.
    /// Deduplicated by `foodName` so each food appears at most once.
    /// Populated by `refreshRecents`; updated in memory after each `insert`.
    private(set) var recentFoods: [FoodLog] = []

    /// All food log entries for the past 7 calendar days (today + 6 prior days).
    /// Ordered by `logged_at` ascending. Used by `ProgressTabView` to build
    /// `DayProgress` totals; updated in memory after each `insert` and `delete`.
    private(set) var weekLogs: [FoodLog] = []

    /// True while `refreshToday` is in flight. Use for subtle loading states.
    private(set) var isRefreshing: Bool = false

    // MARK: - Init

    /// Default initializer — starts with empty state.
    /// Also used as the preview initializer: pass any combination of seeding
    /// parameters in `#Preview` blocks to populate state without a network call.
    init(
        previewLogs:     [FoodLog] = [],
        previewRecents:  [FoodLog] = [],
        previewWeekLogs: [FoodLog] = []
    ) {
        self.todayLogs   = previewLogs
        self.recentFoods = previewRecents
        self.weekLogs    = previewWeekLogs
    }

    // MARK: - Fetch

    /// Fetches `food_logs` rows for `userId` whose `logged_at` falls within today
    /// (midnight → midnight, device local time zone). Replaces `todayLogs` on success.
    ///
    /// Errors are swallowed here — a failed refresh leaves `todayLogs` unchanged
    /// (empty on first load, stale on retry failure) rather than crashing or alerting.
    func refreshToday(userId: UUID) async {
        isRefreshing = true
        defer { isRefreshing = false }

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
            // Non-fatal. Dashboard shows stale/empty data rather than an error state.
        }
    }

    // MARK: - Fetch recents

    /// Fetches the most recently logged distinct foods for `userId` across all days.
    ///
    /// Queries the last 30 entries by `logged_at` descending, then deduplicates
    /// by `foodName` client-side (first occurrence = most recent per food).
    /// The result is capped at 8 entries for a clean UI list.
    ///
    /// Errors are swallowed — `recentFoods` stays as-is on failure.
    func refreshRecents(userId: UUID) async {
        do {
            let logs: [FoodLog] = try await SupabaseClientProvider.shared
                .from("food_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("logged_at", ascending: false)
                .limit(30)
                .execute()
                .value

            // Array is newest-first; the first occurrence of each name is the
            // most recent log for that food — exactly what we want.
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

    /// Fetches all food log entries for `userId` in the past 7 calendar days
    /// (today + the 6 preceding days, in device-local time). Replaces `weekLogs`.
    ///
    /// Errors are swallowed — `weekLogs` stays as-is (empty or stale).
    func refreshWeek(userId: UUID) async {
        do {
            let logs: [FoodLog] = try await SupabaseClientProvider.shared
                .from("food_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: weekStartISO())
                .order("logged_at", ascending: true)
                .execute()
                .value
            weekLogs = logs
        } catch {
            // Non-fatal: ProgressTabView shows whatever data is available.
        }
    }

    // MARK: - Insert

    /// Persists a food log entry to Supabase, then appends the confirmed row to
    /// `todayLogs`, `weekLogs`, and prepends it to `recentFoods`. All three lists
    /// update immediately so views re-render without an extra network round-trip.
    ///
    /// Scaled nutrition values are computed here so the DB row is self-contained:
    /// the dashboard reads them with a plain `SUM`, no further math required.
    func insert(food: FoodItem, quantity: Double, for userId: UUID) async throws {
        let payload = FoodLogInsert(
            userId:       userId,
            foodName:     food.name,
            servingLabel: food.servingSize,
            quantity:     quantity,
            calories:     Int((Double(food.calories) * quantity).rounded()),
            proteinG:     food.proteinG * quantity,
            carbsG:       food.carbsG   * quantity,
            fatG:         food.fatG     * quantity,
            loggedAt:     Date()
        )

        let saved: FoodLog = try await SupabaseClientProvider.shared
            .from("food_logs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        todayLogs.append(saved)
        weekLogs.append(saved)

        // Bubble the newly logged food to the top of recents, keeping the list
        // deduplicated and capped at 8 so the search screen stays current.
        var seen = Set<String>()
        recentFoods = ([saved] + recentFoods)
            .filter { seen.insert($0.foodName).inserted }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Delete

    /// Deletes a food log entry from Supabase, then removes it from `todayLogs`
    /// and `weekLogs`. Throws on network or server errors so the caller can surface
    /// feedback.
    func delete(logId: UUID) async throws {
        try await SupabaseClientProvider.shared
            .from("food_logs")
            .delete()
            .eq("id", value: logId.uuidString)
            .execute()
        todayLogs.removeAll { $0.id == logId }
        weekLogs.removeAll  { $0.id == logId }
    }

    // MARK: - Private helpers

    /// Returns ISO 8601 strings for the start and exclusive end of today in the
    /// device's time zone. Postgres `timestamptz` comparisons are timezone-aware,
    /// so including the UTC offset in the string gives correct results for all locales.
    private func todayRange() -> (start: String, end: String) {
        let calendar = Calendar.current
        let start    = calendar.startOfDay(for: Date())
        let end      = calendar.date(byAdding: .day, value: 1, to: start)!
        let fmt      = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (fmt.string(from: start), fmt.string(from: end))
    }

    /// Returns an ISO 8601 string for midnight 6 days ago (device local time),
    /// i.e. the start of the 7-day window used by `refreshWeek`.
    private func weekStartISO() -> String {
        let calendar  = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let fmt       = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: weekStart)
    }
}

// MARK: - Insert payload

/// Encodable struct for inserting a new row. Excludes server-generated fields
/// (`id`, `created_at`) so Postgres uses its own defaults for them.
private struct FoodLogInsert: Encodable {
    let userId:       UUID
    let foodName:     String
    let servingLabel: String
    let quantity:     Double
    let calories:     Int
    let proteinG:     Double
    let carbsG:       Double
    let fatG:         Double
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
        case loggedAt     = "logged_at"
    }
}
