import Foundation
import Supabase

/// Owns all bodyweight log state and the read/write operations.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `ProgressTabView`
/// is the only current consumer, but the store is app-level so a future
/// dashboard summary can read it without a second fetch.
///
/// ## Guest mode
/// When `guestStore.isActive` is `true`, all operations read from and write to
/// `GuestDataStore` (UserDefaults) instead of Supabase. The in-memory derived
/// list (`weekLogs`) is populated the same way in both modes so views need no
/// conditional logic.
///
/// ## Data lifecycle (authenticated path)
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

    // MARK: - Guest data store

    private let guestStore: GuestDataStore?

    private var isGuest: Bool { guestStore?.isActive == true }

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` from `AkFitApp`.
    ///
    /// Also used as the preview initializer: omit `guestStore` and pass
    /// `previewLogs` to populate state without a network call.
    init(
        guestStore:   GuestDataStore?    = nil,
        previewLogs:  [BodyweightLog]    = []
    ) {
        self.guestStore = guestStore
        self.weekLogs   = previewLogs
    }

    // MARK: - Reset (called when exiting guest mode)

    /// Clears all in-memory log state. Called by `SettingsView` when the user
    /// exits guest mode so stale guest data doesn't persist in memory.
    func reset() {
        weekLogs = []
    }

    // MARK: - Fetch

    /// Fetches all bodyweight entries for `userId` in the past 7 calendar days
    /// (today + 6 prior days, device-local time). Replaces `weekLogs` on success.
    func refreshWeek(userId: UUID) async {
        // Guest path: filter from in-memory guest store.
        if let gs = guestStore, gs.isActive {
            let weekStart = weekStartDate()
            weekLogs = gs.allBodyweightLogs
                .filter { $0.loggedAt >= weekStart }
                .sorted { $0.loggedAt < $1.loggedAt }
            return
        }

        // Authenticated path: Supabase.
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
        let now = Date()

        // Guest path: create locally and persist to GuestDataStore.
        if let gs = guestStore, gs.isActive {
            let log = BodyweightLog(
                id:       UUID(),
                userId:   userId,
                weightKg: weightKg,
                loggedAt: now
            )
            gs.appendBodyweightLog(log)
            weekLogs.append(log)
            weekLogs.sort { $0.loggedAt < $1.loggedAt }
            return
        }

        // Authenticated path: persist to Supabase, update in-memory from confirmed row.
        let payload = BodyweightLogInsert(
            userId:   userId,
            weightKg: weightKg,
            loggedAt: now
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
        // Guest path: remove from GuestDataStore and in-memory list.
        if let gs = guestStore, gs.isActive {
            gs.deleteBodyweightLog(id: logId)
            weekLogs.removeAll { $0.id == logId }
            return
        }

        // Authenticated path: Supabase delete.
        try await SupabaseClientProvider.shared
            .from("bodyweight_logs")
            .delete()
            .eq("id", value: logId.uuidString)
            .execute()
        weekLogs.removeAll { $0.id == logId }
    }

    // MARK: - Private helpers

    /// Returns the start of the 7-day window (6 days ago, device-local midnight).
    private func weekStartDate() -> Date {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -6, to: today)!
    }

    /// ISO 8601 string for midnight 6 days ago in device-local time.
    private func weekStartISO() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: weekStartDate())
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
