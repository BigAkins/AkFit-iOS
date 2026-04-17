import Foundation
import Supabase

/// Owns the user's grocery list — a persistent, date-agnostic ordered checklist.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `SearchView` fetches
/// items on first appear and provides add / toggle / delete / clear-checked actions.
///
/// ## Guest mode
/// When `guestStore.isActive` is true, all operations read from and write to
/// `GuestDataStore` (UserDefaults). In-memory `items` is kept in sync in both
/// modes so views need no conditional logic.
///
/// ## Optimistic updates
/// `toggleItem` and `deleteItem` update `items` immediately before the Supabase
/// call. `toggleItem` reverts on failure. `deleteItem` and `clearChecked` do not
/// revert on failure — the item is already gone from the user's perspective and
/// a silent failure is preferable to a visible flash.
///
/// ## Sort order
/// New items get `sortOrder = max(existing) + 1`. Gaps after deletion are fine;
/// `ORDER BY sort_order ASC` still produces a stable insertion-order list.
@Observable
final class GroceryListStore {

    // MARK: - State

    private(set) var items:     [GroceryItem] = []
    private(set) var isLoading: Bool          = false

    // MARK: - Dependencies

    private let guestStore: GuestDataStore?
    private let authManager: AuthManager?
    private var isGuest: Bool { guestStore?.isActive == true }

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` and
    /// `AuthManager` from `AkFitApp` so authenticated writes can pre-flight
    /// their session via `AuthManager.requireAuthenticatedUserIDForWrite()`.
    init(
        guestStore: GuestDataStore? = nil,
        authManager: AuthManager?   = nil
    ) {
        self.guestStore  = guestStore
        self.authManager = authManager
    }

    // MARK: - Fetch

    /// Fetches all grocery items for the user, ordered by `sortOrder` ascending.
    /// Called by `SearchView` on first appear. Non-fatal on network error.
    func fetchItems(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Guest path: load from GuestDataStore, sort by sort_order.
        if let gs = guestStore, gs.isActive {
            items = gs.allGroceryItems.sorted { $0.sortOrder < $1.sortOrder }
            return
        }

        // Authenticated path: Supabase.
        do {
            let fetched: [GroceryItem] = try await SupabaseClientProvider.shared
                .from("grocery_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("sort_order", ascending: true)
                .execute()
                .value
            items = fetched
        } catch {
            // Non-fatal: items stays empty or retains previous session state.
        }
    }

    // MARK: - Add

    /// Adds a new unchecked item to the end of the list.
    /// Trims whitespace; silently ignores empty strings.
    func addItem(name: String, userId: UUID) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        let now       = Date()

        // Guest path: construct locally and persist.
        if let gs = guestStore, gs.isActive {
            let item = GroceryItem(
                id:        UUID(),
                userId:    userId,
                name:      trimmed,
                isChecked: false,
                sortOrder: nextOrder,
                createdAt: now
            )
            gs.appendGroceryItem(item)
            items.append(item)
            return
        }

        // Authenticated path: validate the session, then insert to Supabase
        // and append the confirmed row.
        do {
            let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
            let payload = GroceryItemInsert(
                id:        UUID(),
                userId:    validUserId,
                name:      trimmed,
                isChecked: false,
                sortOrder: nextOrder
            )
            let saved: GroceryItem = try await SupabaseClientProvider.shared
                .from("grocery_items")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            items.append(saved)
        } catch {
            // Non-fatal: item not added — no optimistic insert to avoid
            // orphaned rows that the user can't remove.
        }
    }

    // MARK: - Toggle

    /// Flips the `isChecked` state of an item.
    /// Updates in memory immediately (optimistic) and reverts on Supabase failure.
    func toggleItem(_ item: GroceryItem, userId: UUID) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newChecked = !items[idx].isChecked
        items[idx].isChecked = newChecked

        // Guest path: persist updated item.
        if let gs = guestStore, gs.isActive {
            gs.updateGroceryItem(items[idx])
            return
        }

        // Authenticated path: validate the session, then partial update.
        do {
            _ = try await authManager?.requireAuthenticatedUserIDForWrite()
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .update(GroceryCheckUpdate(isChecked: newChecked))
                .eq("id", value: item.id.uuidString)
                .execute()
        } catch {
            // Revert optimistic toggle on failure.
            if let revertIdx = items.firstIndex(where: { $0.id == item.id }) {
                items[revertIdx].isChecked = !newChecked
            }
        }
    }

    // MARK: - Delete

    /// Removes a single item. Removes from memory immediately (optimistic).
    func deleteItem(_ item: GroceryItem, userId: UUID) async {
        items.removeAll { $0.id == item.id }

        // Guest path: remove from GuestDataStore.
        if let gs = guestStore, gs.isActive {
            gs.deleteGroceryItem(id: item.id)
            return
        }

        // Authenticated path: validate the session, then Supabase delete.
        // RLS scopes the delete to the owner via `using(auth.uid() = user_id)`.
        do {
            _ = try await authManager?.requireAuthenticatedUserIDForWrite()
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .delete()
                .eq("id", value: item.id.uuidString)
                .execute()
        } catch {
            // Non-fatal: row stays in DB but is removed from in-memory list.
            // Next fetchItems will resync if the user reopens the tab.
        }
    }

    // MARK: - Clear checked

    /// Removes all checked items at once.
    /// Clears from memory immediately, then deletes from Supabase.
    func clearChecked(userId: UUID) async {
        guard items.contains(where: \.isChecked) else { return }
        items.removeAll(where: \.isChecked)

        // Guest path: delegate bulk removal.
        if let gs = guestStore, gs.isActive {
            gs.clearCheckedGroceryItems()
            return
        }

        // Authenticated path: validate the session, then delete all checked
        // rows for this user.
        do {
            let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .delete()
                .eq("user_id", value: validUserId.uuidString)
                .eq("is_checked", value: true)
                .execute()
        } catch {
            // Non-fatal.
        }
    }

    // MARK: - Reset (called when exiting guest mode)

    func reset() {
        items     = []
        isLoading = false
    }
}

// MARK: - Insert payload (authenticated path)

private struct GroceryItemInsert: Encodable {
    let id:        UUID
    let userId:    UUID
    let name:      String
    let isChecked: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId    = "user_id"
        case isChecked = "is_checked"
        case sortOrder = "sort_order"
    }
}

// MARK: - Toggle update payload (authenticated path)

private struct GroceryCheckUpdate: Encodable {
    let isChecked: Bool
    enum CodingKeys: String, CodingKey {
        case isChecked = "is_checked"
    }
}
