import Testing
import Foundation
@testable import AkFit

// MARK: - Store reset tests

/// Pins the per-store `reset()` contract behind RootView's centralized
/// identity-transition hook (`AkFitApp.swift`, `resetUserOwnedStores()`).
///
/// Regression context (2026-06 audit): sign-out previously reset NO stores
/// and the manual per-call-site reset lists had drifted (exit-guest missed
/// favorites), so user A's logs/favorites/grocery/note survived in memory
/// into user B's session on a shared device. The centralized hook resets all
/// six user-owned stores on every `currentUserId` transition; these tests
/// assert each `reset()` actually clears the user-visible state it owns.
struct StoreResetTests {

    // MARK: - Fixtures

    private static func makeFoodLog(name: String = "Chicken Breast") -> FoodLog {
        FoodLog(
            id: UUID(), userId: UUID(),
            foodName: name, servingLabel: "100g",
            quantity: 1.5, calories: 248,
            proteinG: 46.5, carbsG: 0, fatG: 5.4,
            mealSlot: .lunch,
            loggedAt: Date(), createdAt: Date()
        )
    }

    // MARK: - FoodLogStore

    @Test func foodLogStore_reset_clearsAllUserVisibleState() {
        let store = FoodLogStore(
            previewLogs:     [Self.makeFoodLog()],
            previewRecents:  [Self.makeFoodLog(name: "Greek Yogurt")],
            previewWeekLogs: [Self.makeFoodLog(name: "Oats")]
        )
        #expect(!store.todayLogs.isEmpty)
        #expect(!store.recentFoods.isEmpty)
        #expect(!store.weekLogs.isEmpty)

        store.reset()

        #expect(store.todayLogs.isEmpty)
        #expect(store.recentFoods.isEmpty)
        #expect(store.weekLogs.isEmpty)
        #expect(store.dayLogs.isEmpty)
        #expect(store.dayLogsDate == nil)
        #expect(store.lastLoggedEntry == nil)
        #expect(!store.refreshFailed)
    }

    // MARK: - WaterStore

    @Test func waterStore_reset_clearsDayEntries() {
        let entry = WaterEntry(
            id: UUID(), userId: UUID(),
            amountMl: 473, loggedAt: Date(), createdAt: Date()
        )
        let store = WaterStore(previewEntries: [entry])
        #expect(!store.dayEntries.isEmpty)
        #expect(store.dayEntriesDate != nil)

        store.reset()

        #expect(store.dayEntries.isEmpty)
        #expect(store.dayEntriesDate == nil)
        #expect(!store.refreshFailed)
    }

    // MARK: - BodyweightStore

    @Test func bodyweightStore_reset_clearsWeekLogs() {
        let log = BodyweightLog(
            id: UUID(), userId: UUID(),
            weightKg: 82.5, loggedAt: Date(), createdAt: Date()
        )
        let store = BodyweightStore(previewLogs: [log])
        #expect(!store.weekLogs.isEmpty)

        store.reset()

        #expect(store.weekLogs.isEmpty)
    }

    // MARK: - FavoriteFoodStore

    @Test func favoriteFoodStore_reset_clearsFavorites() {
        let fav = FavoriteFood(
            id: UUID(), userId: UUID(),
            foodName: "Peanut Butter", servingLabel: "2 tbsp (32g)",
            servingWeightG: 32, calories: 188,
            proteinG: 8, carbsG: 6, fatG: 16,
            brandOrCategory: nil, createdAt: Date()
        )
        let store = FavoriteFoodStore(previewFavorites: [fav])
        #expect(!store.favorites.isEmpty)

        store.reset()

        #expect(store.favorites.isEmpty)
    }

    // MARK: - DailyNoteStore

    // MainActor: GuestDataStore/DailyNoteStore are MainActor-isolated via the
    // app target's default isolation; without this the async test calls them
    // off-actor (a hard error once the test target adopts Swift 6 mode).
    @Test @MainActor func dailyNoteStore_reset_clearsTodayContent() async throws {
        let suiteName = "StoreResetTests.DailyNote.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let protectedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: protectedDirectory)
        }

        let guestStore = GuestDataStore(
            defaults: defaults,
            protectedDirectory: protectedDirectory
        )
        guestStore.activate()

        let store = DailyNoteStore(guestStore: guestStore)
        let saved = await store.save(content: "Meal prep Sunday", userId: UUID())
        #expect(saved)
        #expect(store.todayContent == "Meal prep Sunday")

        store.reset()

        #expect(store.todayContent.isEmpty)
        #expect(!store.isSaving)
    }

    // MARK: - GroceryListStore

    @Test func groceryListStore_reset_clearsAllUserVisibleState() {
        let item = GroceryItem(
            id: UUID(), userId: UUID(),
            name: "Eggs", isChecked: false, sortOrder: 0, createdAt: Date()
        )
        let store = GroceryListStore(previewItems: [item])
        #expect(!store.items.isEmpty)

        store.reset()

        #expect(store.items.isEmpty)
        #expect(store.actionErrorMessage == nil)
        #expect(!store.isLoading)
        #expect(!store.isAdding)
        #expect(!store.isClearingChecked)
        #expect(!store.isItemBusy(item))
    }
}
