import Foundation
import OSLog
import Supabase

private let dailyNoteLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AkFit",
    category: "DailyNoteStore"
)

/// Owns today's daily note — one free-text note per calendar day.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `DashboardView`
/// fetches today's note on first appear and opens `NoteEditorSheet` for edits.
///
/// ## Guest mode
/// When `guestStore.isActive` is true, the note is read from and written to
/// `GuestDataStore` local persistence. The in-memory `todayContent` string is
/// kept in sync in both modes so views need no conditional logic.
///
/// ## Save behaviour
/// `save(content:userId:)` is called explicitly when the user taps "Done"
/// in the editor sheet. No debouncing — v1 saves once on confirmed exit.
/// The upsert uses the `(user_id, note_date)` unique constraint so there is
/// never an INSERT vs UPDATE decision in client code.
@Observable
final class DailyNoteStore {

    // MARK: - State

    private(set) var todayContent: String = ""
    private(set) var isSaving:     Bool   = false

    // MARK: - Dependencies

    private let guestStore: GuestDataStore?
    private let authManager: AuthManager?
    private var isGuest: Bool { guestStore?.isActive == true }

    private func canApplyUserOwnedState(for userId: UUID) -> Bool {
        guard !Task.isCancelled else { return false }
        guard let authManager else { return true }
        return authManager.currentUserId == userId
    }

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` and
    /// `AuthManager` from `AkFitApp` so `save` can pre-flight the session
    /// via `AuthManager.requireAuthenticatedUserIDForWrite()` on the
    /// authenticated path.
    init(
        guestStore: GuestDataStore? = nil,
        authManager: AuthManager?   = nil
    ) {
        self.guestStore  = guestStore
        self.authManager = authManager
    }

    // MARK: - Fetch

    /// Fetches today's note content. Called by `DashboardView` on first appear.
    /// Non-fatal on network error — `todayContent` stays empty.
    func fetchToday(userId: UUID) async {
        guard canApplyUserOwnedState(for: userId) else { return }
        let key = Self.todayKey

        // Guest path: direct dictionary lookup.
        if let gs = guestStore, gs.isActive {
            todayContent = gs.dailyNote(for: key) ?? ""
            return
        }

        // Authenticated path: single-row select by (user_id, note_date).
        do {
            struct NoteRow: Decodable {
                let content: String
            }
            let rows: [NoteRow] = try await SupabaseClientProvider.shared
                .from("daily_notes")
                .select("content")
                .eq("user_id", value: userId.uuidString)
                .eq("note_date", value: key)
                .limit(1)
                .execute()
                .value
            guard canApplyUserOwnedState(for: userId) else { return }
            todayContent = rows.first?.content ?? ""
        } catch {
            // Non-fatal: content stays at default empty string.
        }
    }

    // MARK: - Save

    /// Persists `content` for today's date, then updates `todayContent` in memory.
    ///
    /// Called when the user taps "Done" in `NoteEditorSheet`. Uses upsert on
    /// the `(user_id, note_date)` unique constraint — no prior fetch needed.
    ///
    /// Returns `false` when the note was NOT persisted (network/session
    /// failure, or the identity changed before the write was issued).
    /// `todayContent` is only mutated after the write is decided, so a
    /// failed save never shows the user content that will vanish on next
    /// launch — the editor keeps the text and surfaces a retry alert instead.
    ///
    /// If the identity changes AFTER a successful upsert, the write has
    /// persisted for the original account, so this still returns `true`;
    /// only the local `todayContent` mutation is skipped (RootView resets
    /// this store on identity transitions).
    func save(content: String, userId: UUID) async -> Bool {
        guard canApplyUserOwnedState(for: userId) else { return false }
        let key = Self.todayKey

        // Guest path: write to UserDefaults dictionary.
        if let gs = guestStore, gs.isActive {
            gs.saveDailyNote(content, for: key)
            todayContent = content
            return true
        }

        // Authenticated path: validate the session, then upsert to Supabase.
        isSaving = true
        defer { isSaving = false }
        do {
            let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
            guard validUserId == userId, canApplyUserOwnedState(for: userId) else {
                dailyNoteLogger.error("daily note save aborted reason=identity_changed")
                return false
            }
            let payload = DailyNoteUpsert(
                userId:    validUserId,
                noteDate:  key,
                content:   content,
                updatedAt: Date()
            )
            try await SupabaseClientProvider.shared
                .from("daily_notes")
                .upsert(payload, onConflict: "user_id,note_date")
                .execute()
            guard canApplyUserOwnedState(for: userId) else { return true }
            todayContent = content
            return true
        } catch {
            let classification = SaveErrorClassification.classification(of: error)
            let postgrestCode = SaveErrorClassification.postgrestCode(of: error)
            let authCode = SaveErrorClassification.authCode(of: error)
            dailyNoteLogger.error(
                "daily note save failed classification=\(classification, privacy: .public) postgrest_code=\(postgrestCode, privacy: .public) auth_code=\(authCode, privacy: .public)"
            )
            SentryMonitoring.captureNonFatal(
                error,
                operation: "daily_note_save",
                tags: [
                    "classification": classification,
                    "postgrest_code": postgrestCode,
                    "auth_code": authCode,
                ]
            )
            return false
        }
    }

    // MARK: - Reset

    /// Clears all user-owned state. Called ONLY by
    /// `RootView.resetUserOwnedStores()` (AkFitApp.swift) on identity
    /// transitions — never from call-site-local reset lists.
    func reset() {
        todayContent = ""
        isSaving     = false
    }

    // MARK: - Date helper

    /// Returns today's date as a `"yyyy-MM-dd"` string — the key used in
    /// both the UserDefaults dictionary and the Supabase `note_date` column.
    static var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat   = "yyyy-MM-dd"
        fmt.locale       = Locale(identifier: "en_US_POSIX")
        fmt.timeZone     = Calendar.current.timeZone
        return fmt.string(from: Date())
    }
}

// MARK: - Upsert payload (authenticated path)

private struct DailyNoteUpsert: Encodable {
    let userId:    UUID
    let noteDate:  String   // "yyyy-MM-dd" — PostgreSQL casts to date
    let content:   String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case noteDate  = "note_date"
        case content
        case updatedAt = "updated_at"
    }
}
