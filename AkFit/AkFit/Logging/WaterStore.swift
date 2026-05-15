import Foundation
import Supabase

/// Owns water entry state and read/write operations.
///
/// Water tracking is event-style: each row is one intake event, and daily
/// totals are calculated by summing the loaded day's entries.
@Observable
final class WaterStore {

    // MARK: - State

    /// Entries for the selected day, ordered by `logged_at` ascending.
    private(set) var dayEntries: [WaterEntry] = []
    /// Start-of-day (device-local) for the day currently loaded.
    private(set) var dayEntriesDate: Date? = nil
    private(set) var isRefreshing: Bool = false
    private(set) var refreshFailed: Bool = false

    /// Total intake for the loaded day.
    var totalMl: Int {
        dayEntries.reduce(0) { $0 + $1.amountMl }
    }

    /// Total intake for the loaded day in US fluid ounces.
    var totalOz: Double {
        WaterEntry.ounces(fromMilliliters: totalMl)
    }

    // MARK: - Dependencies

    private let guestStore: GuestDataStore?
    private let authManager: AuthManager?

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` and
    /// `AuthManager` from `AkFitApp` so authenticated writes can pre-flight
    /// their session via `AuthManager.requireAuthenticatedUserIDForWrite()`.
    init(
        guestStore: GuestDataStore? = nil,
        authManager: AuthManager? = nil,
        previewEntries: [WaterEntry] = []
    ) {
        self.guestStore = guestStore
        self.authManager = authManager
        self.dayEntries = previewEntries
        self.dayEntriesDate = previewEntries.first.map {
            Calendar.current.startOfDay(for: $0.loggedAt)
        }
    }

    // MARK: - Reset

    func reset() {
        dayEntries = []
        dayEntriesDate = nil
        isRefreshing = false
        refreshFailed = false
    }

    // MARK: - Fetch

    /// Fetches water entries for the given calendar day (device-local).
    func refreshDay(userId: UUID, date: Date = Date()) async {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: day)!

        isRefreshing = true
        refreshFailed = false
        defer { isRefreshing = false }

        if let gs = guestStore, gs.isActive {
            dayEntries = gs.allWaterEntries
                .filter { $0.loggedAt >= day && $0.loggedAt < end }
                .sorted { $0.loggedAt < $1.loggedAt }
            dayEntriesDate = day
            return
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startISO = fmt.string(from: day)
        let endISO = fmt.string(from: end)

        do {
            let entries: [WaterEntry] = try await SupabaseClientProvider.shared
                .from("water_entries")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: startISO)
                .lt("logged_at", value: endISO)
                .order("logged_at", ascending: true)
                .execute()
                .value
            dayEntries = entries
            dayEntriesDate = day
        } catch {
            refreshFailed = true
        }
    }

    // MARK: - Add

    /// Adds a water intake event in US fluid ounces.
    func add(amountOz: Double, for userId: UUID, date: Date = Date()) async throws {
        try await add(
            amountMl: WaterEntry.milliliters(fromOunces: amountOz),
            for: userId,
            date: date
        )
    }

    /// Adds a water intake event in milliliters.
    func add(amountMl: Int, for userId: UUID, date: Date = Date()) async throws {
        guard amountMl > 0 && amountMl <= 5000 else {
            throw WaterStoreError.invalidAmount
        }

        let loggedAt = LogDateContext.resolvedLoggedAt(for: date)
        let now = Date()

        if let gs = guestStore, gs.isActive {
            let entry = WaterEntry(
                id: UUID(),
                userId: userId,
                amountMl: amountMl,
                loggedAt: loggedAt,
                createdAt: now
            )
            gs.appendWaterEntry(entry)
            updateInMemory(with: entry)
            return
        }

        let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
        let payload = WaterEntryInsert(
            userId: validUserId,
            amountMl: amountMl,
            loggedAt: loggedAt
        )
        let saved: WaterEntry = try await SupabaseClientProvider.shared
            .from("water_entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        updateInMemory(with: saved)
    }

    // MARK: - Delete

    func delete(entryId: UUID) async throws {
        if let gs = guestStore, gs.isActive {
            gs.deleteWaterEntry(id: entryId)
            dayEntries.removeAll { $0.id == entryId }
            return
        }

        _ = try await authManager?.requireAuthenticatedUserIDForWrite()
        try await SupabaseClientProvider.shared
            .from("water_entries")
            .delete()
            .eq("id", value: entryId.uuidString)
            .execute()
        dayEntries.removeAll { $0.id == entryId }
    }

    // MARK: - Private helpers

    private func updateInMemory(with entry: WaterEntry) {
        let cal = Calendar.current
        if dayEntriesDate == nil {
            dayEntriesDate = cal.startOfDay(for: entry.loggedAt)
        }

        if let date = dayEntriesDate,
           cal.isDate(date, inSameDayAs: entry.loggedAt) {
            dayEntries.append(entry)
            dayEntries.sort { $0.loggedAt < $1.loggedAt }
        }
    }
}

enum WaterStoreError: Error, Equatable {
    case invalidAmount
}

// MARK: - Insert payload

private struct WaterEntryInsert: Encodable {
    let userId: UUID
    let amountMl: Int
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case amountMl = "amount_ml"
        case loggedAt = "logged_at"
    }
}
