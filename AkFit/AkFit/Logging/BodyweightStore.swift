import Foundation
import Supabase

/// Owns all bodyweight log state and the Supabase read/write operations.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `ProgressTabView`
/// is the only current consumer, but the store is app-level so a future
/// dashboard summary can read it without a second fetch.
///
/// ## Data lifecycle
/// 1. `ProgressTabView` calls `refreshWeek(userId:)` via `.task` on first appear,
///    concurrently with the calorie log refresh.
/// 2. `log(weightKg:for:)` inserts a new row and appends it to `weekLogs`.
/// 3. `delete(logId:)` removes a row and updates `weekLogs` in memory.
@Observable
final class BodyweightStore {

    // MARK: - State

    /// Bodyweight entries for the past 7 calendar days (today + 6 prior days),
    /// ordered by `logged_at` ascending. Multiple entries per day are possible —
    /// callers use the latest entry for each calendar day when rendering charts.
    private(set) var weekLogs: [BodyweightLog] = []

    // MARK: - Init

    /// Default initializer — starts with empty state.
    /// Pass `previewLogs` in `#Preview` blocks to populate without a network call.
    init(previewLogs: [BodyweightLog] = []) {
        self.weekLogs = previewLogs
    }

    // MARK: - Fetch

    /// Fetches all bodyweight entries for `userId` in the past 7 calendar days
    /// (today + 6 prior days, device-local time). Replaces `weekLogs` on success.
    func refreshWeek(userId: UUID) async {
        do {
            let logs: [BodyweightLog] = try await SupabaseClientProvider.shared
                .from("bodyweight_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: weekStartISO())
                .order("logged_at", ascending: true)
                .execute()
                .value
            weekLogs = logs
        } catch {
            // Non-fatal: weekLogs stays empty or stale.
        }
    }

    // MARK: - Insert

    /// Inserts a new bodyweight entry for `userId` at the current time.
    ///
    /// On success, appends the confirmed row to `weekLogs` and re-sorts by
    /// `logged_at` ascending so the chart always sees data in order.
    func log(weightKg: Double, for userId: UUID) async throws {
        let payload = BodyweightLogInsert(
            userId:   userId,
            weightKg: weightKg,
            loggedAt: Date()
        )
        let saved: BodyweightLog = try await SupabaseClientProvider.shared
            .from("bodyweight_logs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        weekLogs.append(saved)
        weekLogs.sort { $0.loggedAt < $1.loggedAt }
    }

    // MARK: - Delete

    /// Deletes a bodyweight entry by ID. Throws on failure.
    func delete(logId: UUID) async throws {
        try await SupabaseClientProvider.shared
            .from("bodyweight_logs")
            .delete()
            .eq("id", value: logId.uuidString)
            .execute()
        weekLogs.removeAll { $0.id == logId }
    }

    // MARK: - Private helpers

    /// ISO 8601 string for midnight 6 days ago in device-local time.
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

private struct BodyweightLogInsert: Encodable {
    let userId:   UUID
    let weightKg: Double
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case weightKg = "weight_kg"
        case loggedAt = "logged_at"
    }
}
