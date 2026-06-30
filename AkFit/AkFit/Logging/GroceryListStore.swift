import Foundation
import OSLog
import Supabase

private let groceryListLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AkFit",
    category: "GroceryListStore"
)

/// Owns the user's grocery list — a persistent, date-agnostic ordered checklist.
///
/// Injected into the SwiftUI environment from `AkFitApp`. `SearchView` fetches
/// items on first appear and provides add / toggle / delete / clear-checked actions.
///
/// ## Guest mode
/// When `guestStore.isActive` is true, all operations read from and write to
/// `GuestDataStore` local persistence. In-memory `items` is kept in sync in both
/// modes so views need no conditional logic.
///
/// ## Failure handling
/// User-initiated writes return a `GroceryListActionResult` so the UI can keep
/// typed text intact and show a recoverable message when a weak connection
/// prevents the backend write. Delete paths wait for Supabase confirmation
/// before removing rows locally, which prevents offline taps from looking like
/// successful data loss.
///
/// ## Sort order
/// New items get `sortOrder = max(existing) + 1`. Gaps after deletion are fine;
/// `ORDER BY sort_order ASC` still produces a stable insertion-order list.
@Observable
final class GroceryListStore {

    // MARK: - State

    private(set) var items:     [GroceryItem] = []
    private(set) var isLoading: Bool          = false
    private(set) var isAdding:  Bool          = false
    private(set) var isClearingChecked: Bool  = false
    private(set) var actionErrorMessage: String? = nil

    private var busyItemIDs: Set<UUID> = []
    private var deletedItemIDs: Set<UUID> = []

    // MARK: - Dependencies

    private let guestStore: GuestDataStore?
    private let authManager: AuthManager?
    private let remote: GroceryListRemoteClient
    private var isGuest: Bool { guestStore?.isActive == true }

    // MARK: - Init

    /// Production initializer. Pass the shared `GuestDataStore` and
    /// `AuthManager` from `AkFitApp` so authenticated writes can pre-flight
    /// their session via `AuthManager.requireAuthenticatedUserIDForWrite()`.
    init(
        guestStore: GuestDataStore? = nil,
        authManager: AuthManager?   = nil,
        remote: GroceryListRemoteClient = .live,
        previewItems: [GroceryItem] = []
    ) {
        self.guestStore  = guestStore
        self.authManager = authManager
        self.remote      = remote
        self.items       = previewItems
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
            let fetched = try await remote.fetchItems(userId)
            mergeFetchedItems(fetched)
        } catch {
            reportFailure(error, action: .fetch, surfaceToUser: false)
        }
    }

    // MARK: - Add

    /// Adds a new unchecked item to the end of the list.
    /// Trims whitespace; silently ignores empty strings.
    func addItem(name: String, userId: UUID) async -> GroceryListActionResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignored }
        guard !isAdding else { return .ignored }

        let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        let now       = Date()
        isAdding = true
        defer { isAdding = false }

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
            actionErrorMessage = nil
            return .succeeded
        }

        // Authenticated path: validate the session, then insert to Supabase
        // and append the confirmed row.
        do {
            let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
            let item = GroceryItem(
                id:        UUID(),
                userId:    validUserId,
                name:      trimmed,
                isChecked: false,
                sortOrder: nextOrder,
                createdAt: now
            )
            let saved = try await remote.addItem(item)
            items.append(saved)
            actionErrorMessage = nil
            return .succeeded
        } catch {
            return .failed(reportFailure(error, action: .add))
        }
    }

    // MARK: - Toggle

    /// Flips the `isChecked` state of an item.
    /// Updates in memory immediately (optimistic) and reverts on Supabase failure.
    func toggleItem(_ item: GroceryItem, userId: UUID) async -> GroceryListActionResult {
        guard !busyItemIDs.contains(item.id),
              let idx = items.firstIndex(where: { $0.id == item.id })
        else {
            return .ignored
        }
        let newChecked = !items[idx].isChecked
        items[idx].isChecked = newChecked
        busyItemIDs.insert(item.id)
        defer { busyItemIDs.remove(item.id) }

        // Guest path: persist updated item.
        if let gs = guestStore, gs.isActive {
            gs.updateGroceryItem(items[idx])
            actionErrorMessage = nil
            return .succeeded
        }

        // Authenticated path: validate the session, then partial update.
        do {
            _ = try await authManager?.requireAuthenticatedUserIDForWrite()
            try await remote.updateChecked(item.id, newChecked)
            actionErrorMessage = nil
            return .succeeded
        } catch {
            // Revert optimistic toggle on failure.
            if let revertIdx = items.firstIndex(where: { $0.id == item.id }) {
                items[revertIdx].isChecked = !newChecked
            }
            return .failed(reportFailure(error, action: .toggle))
        }
    }

    // MARK: - Delete

    /// Removes a single item after Supabase confirms the delete.
    func deleteItem(_ item: GroceryItem, userId: UUID) async -> GroceryListActionResult {
        guard !busyItemIDs.contains(item.id),
              items.contains(where: { $0.id == item.id })
        else {
            return .ignored
        }
        busyItemIDs.insert(item.id)
        defer { busyItemIDs.remove(item.id) }

        // Guest path: remove from GuestDataStore.
        if let gs = guestStore, gs.isActive {
            gs.deleteGroceryItem(id: item.id)
            deletedItemIDs.insert(item.id)
            items.removeAll { $0.id == item.id }
            actionErrorMessage = nil
            return .succeeded
        }

        // Authenticated path: validate the session, then Supabase delete.
        // RLS scopes the delete to the owner via `using(auth.uid() = user_id)`.
        do {
            _ = try await authManager?.requireAuthenticatedUserIDForWrite()
            try await remote.deleteItem(item.id)
            deletedItemIDs.insert(item.id)
            items.removeAll { $0.id == item.id }
            actionErrorMessage = nil
            return .succeeded
        } catch {
            return .failed(reportFailure(error, action: .delete))
        }
    }

    // MARK: - Clear checked

    /// Removes all checked items after Supabase confirms the bulk delete.
    func clearChecked(userId: UUID) async -> GroceryListActionResult {
        let checkedIDs = Set(items.filter(\.isChecked).map(\.id))
        guard !checkedIDs.isEmpty, !isClearingChecked else { return .ignored }
        isClearingChecked = true
        busyItemIDs.formUnion(checkedIDs)
        defer {
            isClearingChecked = false
            busyItemIDs.subtract(checkedIDs)
        }

        // Guest path: delegate bulk removal.
        if let gs = guestStore, gs.isActive {
            gs.clearCheckedGroceryItems()
            deletedItemIDs.formUnion(checkedIDs)
            items.removeAll { checkedIDs.contains($0.id) }
            actionErrorMessage = nil
            return .succeeded
        }

        // Authenticated path: validate the session, then delete all checked
        // rows for this user.
        do {
            let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
            try await remote.deleteChecked(validUserId)
            deletedItemIDs.formUnion(checkedIDs)
            items.removeAll { checkedIDs.contains($0.id) }
            actionErrorMessage = nil
            return .succeeded
        } catch {
            return .failed(reportFailure(error, action: .clearChecked))
        }
    }

    func isItemBusy(_ item: GroceryItem) -> Bool {
        busyItemIDs.contains(item.id)
    }

    // MARK: - Reset (called when exiting guest mode)

    func reset() {
        items              = []
        isLoading          = false
        isAdding           = false
        isClearingChecked  = false
        actionErrorMessage = nil
        busyItemIDs        = []
        deletedItemIDs     = []
    }

    private func mergeFetchedItems(_ fetched: [GroceryItem]) {
        let localByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let filtered = fetched
            .filter { !deletedItemIDs.contains($0.id) }
            .map { item in
                busyItemIDs.contains(item.id) ? (localByID[item.id] ?? item) : item
            }
        items = filtered.sorted { $0.sortOrder < $1.sortOrder }
    }

    @discardableResult
    private func reportFailure(
        _ error: Error,
        action: GroceryListAction,
        surfaceToUser: Bool = true
    ) -> String {
        let message = SaveErrorClassification.userMessage(
            for: error,
            action: action.userMessageAction
        )
        if surfaceToUser {
            actionErrorMessage = message
        }

        let classification = SaveErrorClassification.classification(of: error)
        let postgrestCode = SaveErrorClassification.postgrestCode(of: error)
        let authCode = SaveErrorClassification.authCode(of: error)
        groceryListLogger.error(
            "grocery action failed action=\(action.rawValue, privacy: .public) classification=\(classification, privacy: .public) postgrest_code=\(postgrestCode, privacy: .public) auth_code=\(authCode, privacy: .public)"
        )
        SentryMonitoring.captureNonFatal(
            error,
            operation: "grocery_\(action.rawValue)",
            tags: [
                "classification": classification,
                "postgrest_code": postgrestCode,
                "auth_code": authCode,
            ]
        )
        return message
    }
}

enum GroceryListActionResult: Equatable {
    case succeeded
    case failed(String)
    case ignored

    var didSucceed: Bool {
        self == .succeeded
    }
}

private enum GroceryListAction: String {
    case fetch
    case add
    case toggle
    case delete
    case clearChecked = "clear_checked"

    var userMessageAction: String {
        switch self {
        case .fetch:
            return "refresh your grocery list"
        case .add:
            return "add that grocery item"
        case .toggle:
            return "update that grocery item"
        case .delete:
            return "delete that grocery item"
        case .clearChecked:
            return "clear checked grocery items"
        }
    }
}

struct GroceryListRemoteClient {
    var fetchItems: (UUID) async throws -> [GroceryItem]
    var addItem: (GroceryItem) async throws -> GroceryItem
    var updateChecked: (UUID, Bool) async throws -> Void
    var deleteItem: (UUID) async throws -> Void
    var deleteChecked: (UUID) async throws -> Void
}

extension GroceryListRemoteClient {
    static let live = GroceryListRemoteClient(
        fetchItems: { userId in
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("sort_order", ascending: true)
                .execute()
                .value
        },
        addItem: { item in
            let payload = GroceryItemInsert(
                id:        item.id,
                userId:    item.userId,
                name:      item.name,
                isChecked: item.isChecked,
                sortOrder: item.sortOrder
            )
            return try await SupabaseClientProvider.shared
                .from("grocery_items")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        },
        updateChecked: { id, isChecked in
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .update(GroceryCheckUpdate(isChecked: isChecked))
                .eq("id", value: id.uuidString)
                .execute()
        },
        deleteItem: { id in
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        },
        deleteChecked: { userId in
            try await SupabaseClientProvider.shared
                .from("grocery_items")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("is_checked", value: true)
                .execute()
        }
    )
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
