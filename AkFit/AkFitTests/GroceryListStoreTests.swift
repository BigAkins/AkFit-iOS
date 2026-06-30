import Foundation
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
        let isClearingChecked = store.isClearingChecked
        let deleteCheckedUserIDs = remote.deleteCheckedUserIDs

        #expect(message == "Couldn't clear checked grocery items. Please check your connection and try again.")
        #expect(itemIDs == [checked.id, unchecked.id])
        #expect(isClearingChecked == false)
        #expect(deleteCheckedUserIDs == [userId])
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
    var addedItems: [GroceryItem] = []
    var updatedItems: [(id: UUID, isChecked: Bool)] = []
    var deletedItemIDs: [UUID] = []
    var deleteCheckedUserIDs: [UUID] = []

    var fetchError: Error?
    var addError: Error?
    var updateError: Error?
    var deleteError: Error?
    var deleteCheckedError: Error?

    var client: GroceryListRemoteClient {
        GroceryListRemoteClient(
            fetchItems: { [self] _ in
                if let fetchError { throw fetchError }
                return fetchedItems
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
            deleteChecked: { [self] userId in
                deleteCheckedUserIDs.append(userId)
                if let deleteCheckedError { throw deleteCheckedError }
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
