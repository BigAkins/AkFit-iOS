# Graph Report - AkFit  (2026-05-23)

## Corpus Check
- 56 files · ~1,083,193 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 757 nodes · 1306 edges · 25 communities detected
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 295 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]

## God Nodes (most connected - your core abstractions)
1. `AuthManager` - 35 edges
2. `GuestDataStore` - 21 edges
3. `Double` - 20 edges
4. `FoodLogStore` - 18 edges
5. `CodingKeys` - 17 edges
6. `SearchView` - 17 edges
7. `CodingKeys` - 15 edges
8. `DaySummaryTests` - 15 edges
9. `UserGoal` - 14 edges
10. `CodingKeys` - 14 edges

## Surprising Connections (you probably didn't know these)
- `String` --calls--> `formatQuantity()`  [INFERRED]
   → AkFit/AkFit/Views/FoodDetail/FoodDetailView.swift  _Bridges community 5 → community 9_
- `SettingsView` --inherits--> `View`  [EXTRACTED]
  AkFit/AkFit/Views/Settings/SettingsView.swift →   _Bridges community 1 → community 3_
- `ProgressTabView` --inherits--> `View`  [EXTRACTED]
  AkFit/AkFit/Views/Progress/ProgressTabView.swift →   _Bridges community 1 → community 5_
- `WeightLogSheet` --inherits--> `View`  [EXTRACTED]
  AkFit/AkFit/Views/Progress/ProgressTabView.swift →   _Bridges community 1 → community 7_
- `FoodDetailView` --inherits--> `View`  [EXTRACTED]
  AkFit/AkFit/Views/FoodDetail/FoodDetailView.swift →   _Bridges community 1 → community 9_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.04
Nodes (24): AkFitApp, App, BodyweightLogInsert, BodyweightStore, DailyNoteStore, DailyNoteUpsert, Encodable, FavoriteFoodInsert (+16 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (31): DataFetchErrorView, RootView, CalorieSummaryCard, FoodLogRow, MacroCard, MacroRow, NoteEditorSheet, ProgressRing (+23 more)

### Community 2 - "Community 2"
Cohesion: 0.04
Nodes (53): CodingKeys, createdAt, id, loggedAt, userId, weightKg, CodingKeys, loggedAt (+45 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (8): Double, Input, MacroCalculator, Output, MacroCalculatorTests, OnboardingData, SettingsView, UnitConversionTests

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (33): BodyweightLog, Codable, FavoriteFood, FoodItem, FoodLog, FoodSearchService, GroceryItem, Identifiable (+25 more)

### Community 5 - "Community 5"
Cohesion: 0.08
Nodes (8): AuthManager, DeleteAccountError, notAuthenticated, serverError, UserDataResult, LocalizedError, ProgressTabView, String

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (32): Decodable, CodingKeys, brands, carbohydrates100g, carbohydratesServing, energyKcal100g, energyKcalServing, fat100g (+24 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (24): AuthView, Mode, signIn, signUp, CaseIterable, MacroDisplayMode, consumed, percent (+16 more)

### Community 8 - "Community 8"
Cohesion: 0.07
Nodes (21): Equatable, Error, AppUserState, authenticated, guest, signedOut, Keys, AuthStatus (+13 more)

### Community 9 - "Community 9"
Cohesion: 0.07
Nodes (10): BarcodeLookupService, DayProgress, FoodDetailView, formatQuantity(), QuantityStepper, FoodSearchService, HybridFoodSearchService, Int (+2 more)

### Community 10 - "Community 10"
Cohesion: 0.08
Nodes (11): LogDateContextTests, UserProfileTests, WaterEntryTests, LogDateContext, CodingKeys, amountMl, createdAt, id (+3 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (12): AppRouter, AppTab, dashboard, progress, search, settings, Hashable, FoodRow (+4 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (13): CodingKeys, calories, carbsG, fatG, foodName, loggedAt, mealSlot, proteinG (+5 more)

### Community 13 - "Community 13"
Cohesion: 0.16
Nodes (3): QueryMatch, SearchTextMatcher, SearchTextMatcherTests

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (16): BarcodeScannerView, Coordinator, DataScannerRepresentable, ScanState, checkingPermission, looking, notFound, permissionDenied (+8 more)

### Community 15 - "Community 15"
Cohesion: 0.22
Nodes (2): DaySummaryTests, DaySummary

### Community 16 - "Community 16"
Cohesion: 0.17
Nodes (7): AuthStatus, authorized, denied, notDetermined, Keys, NotificationService, UNUserNotificationCenterDelegate

### Community 17 - "Community 17"
Cohesion: 0.15
Nodes (13): CodingKeys, calories, carbsG, createdAt, fatG, foodName, id, loggedAt (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.17
Nodes (12): CodingKeys, createdAt, dailyCalories, dailyCarbs, dailyFat, dailyProtein, goalType, id (+4 more)

### Community 19 - "Community 19"
Cohesion: 0.17
Nodes (12): CodingKeys, brandOrCategory, calories, carbsG, createdAt, fatG, foodName, id (+4 more)

### Community 20 - "Community 20"
Cohesion: 0.18
Nodes (3): AkFitUITests, AkFitUITestsLaunchTests, XCTestCase

### Community 21 - "Community 21"
Cohesion: 0.27
Nodes (1): DashboardView

### Community 22 - "Community 22"
Cohesion: 0.4
Nodes (4): BarcodeLookupResult, found, notFound, BarcodeLookupService

### Community 24 - "Community 24"
Cohesion: 1.0
Nodes (1): AppConfig

### Community 25 - "Community 25"
Cohesion: 1.0
Nodes (1): SupabaseClientProvider

## Knowledge Gaps
- **181 isolated node(s):** `AppConfig`, `notAuthenticated`, `serverError`, `notDetermined`, `authorized` (+176 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 15`** (18 nodes): `DaySummary.swift`, `DaySummaryTests`, `.addConsumed_addsPreScaledMacros()`, `.addConsumed_stacksOnExistingConsumption()`, `.calorieProgress_halfConsumedReturnsDotFive()`, `.from_goalLogs_emptyLogsLeavesConsumedZero()`, `.from_goalLogs_matchesManualLoop()`, `.from_goalLogs_sumsPreScaledMacros()`, `.makeGoal()`, `.makeLog()`, `.progress_clampedAtOneWhenOverBudget()`, `.progress_zeroWhenTargetIsZero()`, `.remaining_clampedAtZeroWhenOverBudget()`, `.remaining_exactlyAtTargetIsZero()`, `.remaining_subtractsConsumedFromTarget()`, `DaySummary`, `.addConsumed()`, `.from()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 21`** (10 nodes): `DashboardView`, `.addWater()`, `.goToToday()`, `.greetingText()`, `.isBirthday()`, `.logs()`, `.mealSectionHeader()`, `.slotCalories()`, `.stepDay()`, `.undoLastWater()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (2 nodes): `AppConfig.swift`, `AppConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (2 nodes): `SupabaseClientProvider.swift`, `SupabaseClientProvider`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthManager` connect `Community 5` to `Community 0`, `Community 7`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Why does `SearchView` connect `Community 11` to `Community 8`, `Community 1`, `Community 13`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Why does `NotificationService` connect `Community 16` to `Community 0`, `Community 14`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 22 inferred relationships involving `String` (e.g. with `.requireAuthenticatedUserIDForWrite()` and `.setPendingAppleCredentials()`) actually correct?**
  _`String` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `AuthManager` (e.g. with `.init()` and `.previewAuth()`) actually correct?**
  _`AuthManager` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 20 inferred relationships involving `Int` (e.g. with `.toFoodItem()` and `.cleanServingLabel()`) actually correct?**
  _`Int` has 20 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppConfig`, `notAuthenticated`, `serverError` to the rest of the system?**
  _181 weakly-connected nodes found - possible documentation gaps or missing edges._