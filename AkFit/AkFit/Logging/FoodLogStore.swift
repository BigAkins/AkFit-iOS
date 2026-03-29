import Foundation
import Supabase

/// Owns all in-session food log state and the Supabase read/write operations.
///
/// Injected into the SwiftUI environment from `AkFitApp`. Both `DashboardView`
/// (reads `todayLogs` for consumed totals) and `FoodDetailView` (calls `insert`)
/// share this single instance — no extra network round-trip needed after logging.
///
/// ## Data lifecycle
/// 1. `DashboardView` calls `refreshToday(userId:)` via `.task` on first appear.
/// 2. `FoodDetailView` calls `insert(food:quantity:for:)` on "Log food" tap.
/// 3. On successful insert, the confirmed row is appended to `todayLogs`
///    immediately — the dashboard re-renders via Observation without a refetch.
@Observable
final class FoodLogStore {

    // MARK: - State

    /// All confirmed food log entries for the current calendar day (device local time).
    private(set) var todayLogs: [FoodLog] = []

    /// True while `refreshToday` is in flight. Use for subtle loading states.
    private(set) var isRefreshing: Bool = false

    // MARK: - Init

    /// Production initializer — starts with an empty log list.
    init() {}

    /// Preview initializer — seeds `todayLogs` without any network call.
    /// Only use inside `#Preview` blocks; production code always uses `init()`.
    init(previewLogs: [FoodLog]) {
        self.todayLogs = previewLogs
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

    // MARK: - Insert

    /// Persists a food log entry to Supabase, then appends the confirmed row to
    /// `todayLogs`. Throws on network or server errors so `FoodDetailView` can
    /// surface feedback to the user.
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
