import Foundation
import Supabase
import Testing
@testable import AkFit

@MainActor
struct GroceryListStoreTests {

    @Test func addFailureDoesNotMutateItemsAndReportsRetryableMessage() async {
        let userId = UUID()
        let remote = GroceryListRemoteSpy()
        remote.addError = URLError(.notConnectedToInternet)
        let store = GroceryListStore(remote: remote.client)

        let result = await store.addItem(name: "  Milk  ", userId: userId)
        let message = failureMessage(from: result)
        let actionErrorMessage = store.actionErrorMessage
        let items = store.items
        let isAdding = store.isAdding
        let addedNames = remote.addedItems.map { $0.name }

        #expect(message == "Couldn't add that grocery item. Please check your connection and try again.")
        #expect(actionErrorMessage == "Couldn't add that grocery item. Please check your connection and try again.")
        #expect(items.isEmpty)
        #expect(isAdding == false)
        #expect(addedNames == ["Milk"])
    }

    @Test func emptyAddIsIgnoredWithoutSettingError() async {
        let remote = GroceryListRemoteSpy()
        let store = GroceryListStore(remote: remote.client)

        let result = await store.addItem(name: "   ", userId: UUID())
        let wasIgnored = isIgnored(result)
        let actionErrorMessage = store.actionErrorMessage
        let addedItems = remote.addedItems

        #expect(wasIgnored)
        #expect(actionErrorMessage == nil)
        #expect(addedItems.isEmpty)
    }

    @Test func toggleFailureRevertsOptimisticStateAndReportsError() async {
        let userId = UUID()
        let item = makeGroceryItem(userId: userId, isChecked: false)
        let remote = GroceryListRemoteSpy()
        remote.updateError = URLError(.timedOut)
        let store = GroceryListStore(remote: remote.client, previewItems: [item])

        let result = await store.toggleItem(item, userId: userId)
        let message = failureMessage(from: result)
        let isChecked = store.items.first?.isChecked
        let actionErrorMessage = store.actionErrorMessage
        let updatedIDs = remote.updatedItems.map { $0.id }
        let updatedCheckedValues = remote.updatedItems.map { $0.isChecked }

        #expect(message == "Couldn't update that grocery item. Please check your connection and try again.")
        #expect(isChecked == false)
        #expect(actionErrorMessage == "Couldn't update that grocery item. Please check your connection and try again.")
        #expect(updatedIDs == [item.id])
        #expect(updatedCheckedValues == [true])
    }

    @Test func deleteFailureKeepsItemVisibleAndReportsError() async {
        let userId = UUID()
        let item = makeGroceryItem(userId: userId)
        let remote = GroceryListRemoteSpy()
        remote.deleteError = URLError(.notConnectedToInternet)
        let store = GroceryListStore(remote: remote.client, previewItems: [item])

        let result = await store.deleteItem(item, userId: userId)
        let message = failureMessage(from: result)
        let itemIDs = store.items.map { $0.id }
        let actionErrorMessage = store.actionErrorMessage
        let deletedItemIDs = remote.deletedItemIDs

        #expect(message == "Couldn't delete that grocery item. Please check your connection and try again.")
        #expect(itemIDs == [item.id])
        #expect(actionErrorMessage == "Couldn't delete that grocery item. Please check your connection and try again.")
        #expect(deletedItemIDs == [item.id])
    }

    @Test func staleFetchAfterSuccessfulDeleteDoesNotResurrectItem() async {
        let userId = UUID()
        let item = makeGroceryItem(userId: userId)
        let remote = GroceryListRemoteSpy()
        let store = GroceryListStore(remote: remote.client, previewItems: [item])

        let deleteResult = await store.deleteItem(item, userId: userId)
        let deleteSucceeded = didSucceed(deleteResult)
        let itemsAfterDelete = store.items
        #expect(deleteSucceeded)
        #expect(itemsAfterDelete.isEmpty)

        remote.fetchedItems = [item]
        await store.fetchItems(userId: userId)
        let itemsAfterStaleFetch = store.items

        #expect(itemsAfterStaleFetch.isEmpty)
    }

    @Test func staleFetchAfterSuccessfulAddDoesNotHideConfirmedItem() async {
        let userId = UUID()
        let remote = GroceryListRemoteSpy()
        remote.suspendedFetchUserID = userId
        let store = GroceryListStore(remote: remote.client)

        let staleFetchTask = Task {
            await store.fetchItems(userId: userId)
        }
        await remote.waitForSuspendedFetch()
        #expect(remote.isFetchSuspended)
        guard remote.isFetchSuspended else {
            staleFetchTask.cancel()
            return
        }

        let addResult = await store.addItem(name: "Milk", userId: userId)
        let addedItem = store.items.first
        #expect(didSucceed(addResult))
        #expect(addedItem?.name == "Milk")

        remote.completeFetch(with: [])
        await staleFetchTask.value

        #expect(store.items.map(\.id) == addedItem.map { [$0.id] } ?? [])
        #expect(store.items.first?.name == "Milk")
    }

    @Test func staleFetchAfterSuccessfulToggleDoesNotRevertCheckedState() async {
        let userId = UUID()
        let item = makeGroceryItem(userId: userId, isChecked: false)
        let remote = GroceryListRemoteSpy()
        remote.suspendedFetchUserID = userId
        let store = GroceryListStore(remote: remote.client, previewItems: [item])

        let staleFetchTask = Task {
            await store.fetchItems(userId: userId)
        }
        await remote.waitForSuspendedFetch()
        #expect(remote.isFetchSuspended)
        guard remote.isFetchSuspended else {
            staleFetchTask.cancel()
            return
        }

        let toggleResult = await store.toggleItem(item, userId: userId)
        #expect(didSucceed(toggleResult))
        #expect(store.items.first?.isChecked == true)

        remote.completeFetch(with: [item])
        await staleFetchTask.value

        #expect(store.items.map(\.id) == [item.id])
        #expect(store.items.first?.isChecked == true)
    }

    @Test func currentUserFetchAppliesWithAuthIdentityGuard() async {
        let userId = UUID()
        let item = makeGroceryItem(userId: userId)
        let manager = AuthManager(previewMode: true)
        let remote = GroceryListRemoteSpy()
        remote.fetchedItemsByUserID[userId] = [item]
        let store = GroceryListStore(authManager: manager, remote: remote.client)

        await manager.handle(event: .signedIn, session: makeSession(userId: userId))
        await store.fetchItems(userId: userId)

        #expect(store.items.map(\.id) == [item.id])

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func staleFetchForOldUserDoesNotOverwriteCurrentUserAfterAccountSwitch() async {
        let oldUserId = UUID()
        let newUserId = UUID()
        let oldItem = makeGroceryItem(userId: oldUserId, name: "Old Milk")
        let newItem = makeGroceryItem(userId: newUserId, name: "New Eggs")
        let manager = AuthManager(previewMode: true)
        let remote = GroceryListRemoteSpy()
        remote.suspendedFetchUserID = oldUserId
        remote.fetchedItemsByUserID[newUserId] = [newItem]
        let store = GroceryListStore(authManager: manager, remote: remote.client)

        await manager.handle(event: .signedIn, session: makeSession(userId: oldUserId))
        let staleFetchTask = Task {
            await store.fetchItems(userId: oldUserId)
        }
        await remote.waitForSuspendedFetch()
        #expect(remote.isFetchSuspended)
        guard remote.isFetchSuspended else {
            staleFetchTask.cancel()
            return
        }

        await manager.handle(event: .signedIn, session: makeSession(userId: newUserId))
        store.reset()
        await store.fetchItems(userId: newUserId)
        #expect(store.items.map(\.id) == [newItem.id])

        remote.completeFetch(with: [oldItem])
        await staleFetchTask.value

        #expect(store.items.map(\.id) == [newItem.id])

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func clearCheckedFailureKeepsItemsVisibleAndReportsError() async {
        let userId = UUID()
        let checked = makeGroceryItem(userId: userId, name: "Eggs", isChecked: true)
        let unchecked = makeGroceryItem(userId: userId, name: "Rice", isChecked: false, sortOrder: 1)
        let remote = GroceryListRemoteSpy()
        remote.deleteCheckedError = URLError(.cannotConnectToHost)
        let store = GroceryListStore(remote: remote.client, previewItems: [checked, unchecked])

        let result = await store.clearChecked(userId: userId)
        let message = failureMessage(from: result)
        let itemIDs = store.items.map { $0.id }
        let checkedStates = store.items.map(\.isChecked)
        let isClearingChecked = store.isClearingChecked
        let deleteCheckedRequests = remote.deleteCheckedRequests

        #expect(message == "Couldn't clear checked grocery items. Please check your connection and try again.")
        #expect(itemIDs == [checked.id, unchecked.id])
        #expect(checkedStates == [true, false])
        #expect(isClearingChecked == false)
        #expect(deleteCheckedRequests.map(\.userId) == [userId])
        #expect(deleteCheckedRequests.map(\.itemIDs) == [Set([checked.id])])
    }

    @Test func clearCheckedDeletesOnlyCapturedIDsWhenAnotherItemIsCheckedDuringClear() async {
        let userId = UUID()
        let checked = makeGroceryItem(userId: userId, name: "Eggs", isChecked: true)
        let unchecked = makeGroceryItem(userId: userId, name: "Rice", isChecked: false, sortOrder: 1)
        let remote = GroceryListRemoteSpy()
        remote.shouldSuspendDeleteChecked = true
        let store = GroceryListStore(remote: remote.client, previewItems: [checked, unchecked])

        let clearTask = Task {
            await store.clearChecked(userId: userId)
        }
        await remote.waitForSuspendedDeleteChecked()
        #expect(remote.isDeleteCheckedSuspended)
        guard remote.isDeleteCheckedSuspended else {
            clearTask.cancel()
            return
        }

        let toggleResult = await store.toggleItem(unchecked, userId: userId)
        #expect(didSucceed(toggleResult))
        #expect(store.items.first(where: { $0.id == unchecked.id })?.isChecked == true)

        remote.completeDeleteChecked()
        let clearResult = await clearTask.value

        #expect(didSucceed(clearResult))
        #expect(remote.deleteCheckedRequests.map(\.userId) == [userId])
        #expect(remote.deleteCheckedRequests.map(\.itemIDs) == [Set([checked.id])])
        #expect(store.items.map(\.id) == [unchecked.id])
        #expect(store.items.first?.isChecked == true)
    }
}

private func failureMessage(from result: GroceryListActionResult) -> String? {
    guard case let .failed(message) = result else { return nil }
    return message
}

private func isIgnored(_ result: GroceryListActionResult) -> Bool {
    guard case .ignored = result else { return false }
    return true
}

private func didSucceed(_ result: GroceryListActionResult) -> Bool {
    guard case .succeeded = result else { return false }
    return true
}

private final class GroceryListRemoteSpy {
    var fetchedItems: [GroceryItem] = []
    var fetchedItemsByUserID: [UUID: [GroceryItem]] = [:]
    var addedItems: [GroceryItem] = []
    var updatedItems: [(id: UUID, isChecked: Bool)] = []
    var deletedItemIDs: [UUID] = []
    var deleteCheckedRequests: [(userId: UUID, itemIDs: Set<UUID>)] = []

    var fetchError: Error?
    var addError: Error?
    var updateError: Error?
    var deleteError: Error?
    var deleteCheckedError: Error?

    var suspendedFetchUserID: UUID?
    private var suspendedFetchContinuation: CheckedContinuation<[GroceryItem], Error>?
    var shouldSuspendDeleteChecked = false
    private var suspendedDeleteCheckedContinuation: CheckedContinuation<Void, Error>?

    var isFetchSuspended: Bool {
        suspendedFetchContinuation != nil
    }

    var isDeleteCheckedSuspended: Bool {
        suspendedDeleteCheckedContinuation != nil
    }

    func waitForSuspendedFetch() async {
        for _ in 0..<100 where suspendedFetchContinuation == nil {
            await Task.yield()
        }
    }

    func waitForSuspendedDeleteChecked() async {
        for _ in 0..<100 where suspendedDeleteCheckedContinuation == nil {
            await Task.yield()
        }
    }

    func completeFetch(with items: [GroceryItem]) {
        suspendedFetchContinuation?.resume(returning: items)
        suspendedFetchContinuation = nil
    }

    func completeDeleteChecked() {
        suspendedDeleteCheckedContinuation?.resume()
        suspendedDeleteCheckedContinuation = nil
    }

    var client: GroceryListRemoteClient {
        GroceryListRemoteClient(
            fetchItems: { [self] userId in
                if let fetchError { throw fetchError }
                if suspendedFetchUserID == userId {
                    return try await withCheckedThrowingContinuation { continuation in
                        suspendedFetchContinuation = continuation
                    }
                }
                return fetchedItemsByUserID[userId] ?? fetchedItems
            },
            addItem: { [self] item in
                addedItems.append(item)
                if let addError { throw addError }
                return item
            },
            updateChecked: { [self] id, isChecked in
                updatedItems.append((id, isChecked))
                if let updateError { throw updateError }
            },
            deleteItem: { [self] id in
                deletedItemIDs.append(id)
                if let deleteError { throw deleteError }
            },
            deleteChecked: { [self] userId, itemIDs in
                deleteCheckedRequests.append((userId, itemIDs))
                if let deleteCheckedError { throw deleteCheckedError }
                if shouldSuspendDeleteChecked {
                    try await withCheckedThrowingContinuation { continuation in
                        suspendedDeleteCheckedContinuation = continuation
                    }
                }
            }
        )
    }
}

private func makeGroceryItem(
    id: UUID = UUID(),
    userId: UUID,
    name: String = "Milk",
    isChecked: Bool = false,
    sortOrder: Int = 0
) -> GroceryItem {
    GroceryItem(
        id: id,
        userId: userId,
        name: name,
        isChecked: isChecked,
        sortOrder: sortOrder,
        createdAt: Date(timeIntervalSince1970: 1_720_000_000)
    )
}

private func makeSession(userId: UUID) -> Session {
    let now = Date()
    let user = User(
        id: userId,
        appMetadata: [:],
        userMetadata: [:],
        aud: "authenticated",
        email: "user@example.com",
        createdAt: now,
        updatedAt: now
    )

    return Session(
        accessToken: "access-token",
        tokenType: "bearer",
        expiresIn: 3_600,
        expiresAt: now.addingTimeInterval(3_600).timeIntervalSince1970,
        refreshToken: "refresh-token",
        user: user
    )
}
