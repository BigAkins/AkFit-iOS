import Foundation
import Supabase

/// Owns today's daily note — one free-text note per calendar day.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `DashboardView`
/// fetches today's note on first appear and opens `NoteEditorSheet` for edits.
///
/// ## Guest mode
/// When `guestStore.isActive` is true, the note is read from and written to
/// `GuestDataStore` (UserDefaults). The in-memory `todayContent` string is
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

    // MARK: - Guest store

    private let guestStore: GuestDataStore?
    private var isGuest: Bool { guestStore?.isActive == true }

    // MARK: - Init

    init(guestStore: GuestDataStore? = nil) {
        self.guestStore = guestStore
    }

    // MARK: - Fetch

    /// Fetches today's note content. Called by `DashboardView` on first appear.
    /// Non-fatal on network error — `todayContent` stays empty.
    func fetchToday(userId: UUID) async {
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
            todayContent = rows.first?.content ?? ""
        } catch {
            // Non-fatal: content stays at default empty string.
        }
    }

    // MARK: - Save

    /// Persists `content` for today's date and updates `todayContent` in memory.
    ///
    /// Called when the user taps "Done" in `NoteEditorSheet`. Uses upsert on
    /// the `(user_id, note_date)` unique constraint — no prior fetch needed.
    func save(content: String, userId: UUID) async {
        todayContent = content
        let key = Self.todayKey

        // Guest path: write to UserDefaults dictionary.
        if let gs = guestStore, gs.isActive {
            gs.saveDailyNote(content, for: key)
            return
        }

        // Authenticated path: upsert to Supabase.
        isSaving = true
        defer { isSaving = false }
        do {
            let payload = DailyNoteUpsert(
                userId:    userId,
                noteDate:  key,
                content:   content,
                updatedAt: Date()
            )
            try await SupabaseClientProvider.shared
                .from("daily_notes")
                .upsert(payload, onConflict: "user_id,note_date")
                .execute()
        } catch {
            // Non-fatal: the in-memory update already happened. The next
            // successful save will persist it.
        }
    }

    // MARK: - Reset (called when exiting guest mode)

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
