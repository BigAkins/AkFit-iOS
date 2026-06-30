import Foundation
import Testing
@testable import AkFit

struct GuestDataStorePersistenceTests {

    @Test func validPersistedGuestDataDecodesNormally() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let foodLog = makeFoodLog(name: "Chicken", mealSlot: .breakfast)
        let bodyweightLog = BodyweightLog(
            id: UUID(), userId: foodLog.userId,
            weightKg: 82.5, loggedAt: fixedDate, createdAt: fixedDate
        )
        let waterEntry = WaterEntry(
            id: UUID(), userId: foodLog.userId,
            amountMl: 473, loggedAt: fixedDate, createdAt: fixedDate
        )
        let groceryItem = GroceryItem(
            id: UUID(), userId: foodLog.userId,
            name: "Eggs", isChecked: false, sortOrder: 0, createdAt: fixedDate
        )

        defaults.set(try encode([foodLog]), forKey: "guest.foodLogs")
        defaults.set(try encode([bodyweightLog]), forKey: "guest.bodyweightLogs")
        defaults.set(try encode([waterEntry]), forKey: "guest.waterEntries")
        defaults.set(try encode(["2026-06-29": "Meal prep"]), forKey: "guest.dailyNotes")
        defaults.set(try encode([groceryItem]), forKey: "guest.groceryItems")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.allFoodLogs.map(\.foodName) == ["Chicken"])
        #expect(store.allFoodLogs.first?.mealSlot == .breakfast)
        #expect(store.allBodyweightLogs.first?.weightKg == 82.5)
        #expect(store.allWaterEntries.first?.amountMl == 473)
        #expect(store.dailyNote(for: "2026-06-29") == "Meal prep")
        #expect(store.allGroceryItems.first?.name == "Eggs")
    }

    @Test func missingMealSlotDefaultsToSnackWithoutOverwritingStorage() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let legacyData = try jsonData([
            foodLogJSON(name: "Legacy Oats", mealSlot: nil)
        ])
        defaults.set(legacyData, forKey: "guest.foodLogs")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.allFoodLogs.count == 1)
        #expect(store.allFoodLogs.first?.foodName == "Legacy Oats")
        #expect(store.allFoodLogs.first?.mealSlot == .snack)
        #expect(defaults.data(forKey: "guest.foodLogs") == legacyData)
    }

    @Test func invalidMealSlotDefaultsToSnackWithoutDroppingItem() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        defaults.set(try jsonData([
            foodLogJSON(name: "Unknown Slot", mealSlot: "brunch")
        ]), forKey: "guest.foodLogs")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.allFoodLogs.count == 1)
        #expect(store.allFoodLogs.first?.foodName == "Unknown Slot")
        #expect(store.allFoodLogs.first?.mealSlot == .snack)
    }

    @Test func partiallyCorruptFoodLogArrayPreservesValidItemsAndAppendKeepsRecoveredData() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let originalData = try jsonData([
            foodLogJSON(name: "Valid A", mealSlot: "lunch"),
            foodLogJSON(name: "Corrupt", mealSlot: "dinner", calories: "not-an-int"),
            foodLogJSON(name: "Valid B", mealSlot: "snack"),
        ])
        defaults.set(originalData, forKey: "guest.foodLogs")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.allFoodLogs.map(\.foodName) == ["Valid A", "Valid B"])
        #expect(defaults.data(forKey: "guest.foodLogs") == originalData)

        store.appendFoodLog(makeFoodLog(name: "New Log", mealSlot: .dinner))

        let reloaded = GuestDataStore(defaults: defaults)
        #expect(reloaded.allFoodLogs.map(\.foodName) == ["Valid A", "Valid B", "New Log"])
        #expect(!reloaded.allFoodLogs.map(\.foodName).contains("Corrupt"))
    }

    @Test func unreadableFoodLogArrayDoesNotImmediatelyOverwriteStorageWithEmptyArray() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let corruptData = Data("{not-json".utf8)
        defaults.set(corruptData, forKey: "guest.foodLogs")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.allFoodLogs.isEmpty)
        #expect(defaults.data(forKey: "guest.foodLogs") == corruptData)
    }

    @Test func groceryUpdateAndDeleteStillWorkAfterLossyDecode() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let validId = UUID()
        let userId = UUID()
        let originalData = try jsonData([
            groceryItemJSON(id: validId, userId: userId, name: "Milk", isChecked: false),
            groceryItemJSON(id: UUID(), userId: userId, name: 42, isChecked: false),
        ])
        defaults.set(originalData, forKey: "guest.groceryItems")

        let store = GuestDataStore(defaults: defaults)
        #expect(store.allGroceryItems.map(\.name) == ["Milk"])
        #expect(defaults.data(forKey: "guest.groceryItems") == originalData)

        var updated = try #require(store.allGroceryItems.first)
        updated.isChecked = true
        store.updateGroceryItem(updated)

        let reloadedAfterUpdate = GuestDataStore(defaults: defaults)
        #expect(reloadedAfterUpdate.allGroceryItems.first?.isChecked == true)

        store.deleteGroceryItem(id: validId)

        let reloadedAfterDelete = GuestDataStore(defaults: defaults)
        #expect(reloadedAfterDelete.allGroceryItems.isEmpty)
    }

    @Test func partiallyCorruptDailyNotesPreserveValidNotesWithoutImmediateOverwrite() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }

        let originalData = try jsonData([
            "2026-06-29": "High protein day",
            "2026-06-30": 123,
        ])
        defaults.set(originalData, forKey: "guest.dailyNotes")

        let store = GuestDataStore(defaults: defaults)

        #expect(store.dailyNote(for: "2026-06-29") == "High protein day")
        #expect(store.dailyNote(for: "2026-06-30") == nil)
        #expect(defaults.data(forKey: "guest.dailyNotes") == originalData)
    }
}

// MARK: - Fixtures

private let fixedDate = Date(timeIntervalSince1970: 1_720_000_000)
private let fixedDateString = ISO8601DateFormatter().string(from: fixedDate)

private func makeDefaults() throws -> (UserDefaults, () -> Void) {
    let suiteName = "GuestDataStorePersistenceTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, {
        defaults.removePersistentDomain(forName: suiteName)
    })
}

private func encode<T: Encodable>(_ value: T) throws -> Data {
    try GuestDataStore.encoder.encode(value)
}

private func jsonData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
}

private func makeFoodLog(name: String, mealSlot: MealSlot) -> FoodLog {
    FoodLog(
        id: UUID(), userId: UUID(),
        foodName: name, servingLabel: "100g",
        quantity: 1, calories: 120,
        proteinG: 12, carbsG: 10, fatG: 4,
        mealSlot: mealSlot,
        loggedAt: fixedDate, createdAt: fixedDate
    )
}

private func foodLogJSON(
    name: String,
    mealSlot: String?,
    calories: Any = 120
) -> [String: Any] {
    var object: [String: Any] = [
        "id": UUID().uuidString,
        "user_id": UUID().uuidString,
        "food_name": name,
        "serving_label": "100g",
        "quantity": 1,
        "calories": calories,
        "protein_g": 12,
        "carbs_g": 10,
        "fat_g": 4,
        "logged_at": fixedDateString,
        "created_at": fixedDateString,
    ]
    if let mealSlot {
        object["meal_slot"] = mealSlot
    }
    return object
}

private func groceryItemJSON(
    id: UUID,
    userId: UUID,
    name: Any,
    isChecked: Bool
) -> [String: Any] {
    [
        "id": id.uuidString,
        "user_id": userId.uuidString,
        "name": name,
        "is_checked": isChecked,
        "sort_order": 0,
        "created_at": fixedDateString,
    ]
}
