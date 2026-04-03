import SwiftUI

/// Food search screen — the entry point for the logging loop.
///
/// Reachable directly via the Search tab or by tapping the dashboard FAB
/// (which sets `AppRouter.selectedTab = .search`).
///
/// **Daily summary:** a compact card at the top of the empty state and
/// results list shows remaining calories + P/C/F, computed from
/// `authManager.goal` and `logStore.todayLogs` (both already in memory).
/// Updates live as the user logs foods without any extra network calls.
///
/// **Empty state:** shows a "Recent" section (last 8 distinct foods logged,
/// newest first) above a "Suggestions" list pulled from Supabase
/// `generic_foods`. Both are fetched concurrently on first appear.
///
/// **Search state:** uses `HybridFoodSearchService` — Supabase generic foods
/// first, Open Food Facts fallback for branded/packaged items. A 250 ms
/// debounce coalesces rapid keystrokes before the first network hop fires,
/// so the search only triggers once the user pauses.
///
/// Tapping any row pushes `FoodDetailView` where the user adjusts quantity
/// and taps "Log food" to persist the entry.
struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [FoodItem] = []
    @State private var suggestions: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showScanner = false
    /// Set when a barcode scan resolves to a food item. Triggers navigation to `FoodDetailView`.
    @State private var scannedFood: FoodItem? = nil
    /// Staging area: holds the scanned food until the scanner cover fully dismisses,
    /// then promotes it to `scannedFood` via `onDismiss`. This ensures the navigation
    /// push happens after the cover animation completes — no overlapping transitions.
    @State private var pendingScannedFood: FoodItem? = nil
    /// The log entry currently shown in the confirmation banner. Nil hides the banner.
    @State private var bannerEntry: FoodLog? = nil
    @State private var autoDismissTask: Task<Void, Never>? = nil

    @Environment(FoodLogStore.self)         private var logStore
    @Environment(FavoriteFoodStore.self)    private var favStore
    @Environment(GroceryListStore.self)     private var groceryStore
    @Environment(AuthManager.self)          private var authManager
    @Environment(HealthKitService.self)     private var healthKit
    @Environment(NotificationService.self)  private var notifications
    @Environment(AppRouter.self)            private var router

    @State private var newGroceryItem: String = ""
    /// Guards against rapid double-tap on swipe-to-log (quick-log) actions.
    /// Set `true` before the insert call; cleared after it completes.
    @State private var isQuickLogging = false
    /// Food names and brand names from the database, used as the type-ahead
    /// suggestion pool. Fetched once on first appear. Guaranteed searchable.
    @State private var typeAheadTerms: [String] = []
    /// Stable snapshot of matching suggestions for the current query.
    /// Updated explicitly in `.onChange(of: query)` so the panel never reads
    /// a mid-transition or recomputed value during rendering.
    @State private var displayedSuggestions: [String] = []
    /// Explicitly managed show/hide state for the suggestion overlay.
    /// Mutated ONLY inside `withAnimation` blocks so the animation is scoped
    /// to the opacity/offset transition and never bleeds into child text content.
    @State private var showSuggestionPanel = false
    /// Set `true` right before a programmatic `query` change (suggestion tap)
    /// so `onChange(of: query)` knows to skip its suggestion-refresh logic.
    @State private var hasCommitted = false
    /// Set `true` when the user explicitly commits a search (tap suggestion or
    /// keyboard Search). Reset to `false` on every manual keystroke. Controls
    /// whether the "No results" message shows (only after a real search attempt).
    @State private var hasSearchedCurrentQuery = false

    private let searchService: any FoodSearchService = HybridFoodSearchService()
    /// Used exclusively to populate the empty-state suggestions from Supabase.
    private let suggestionService = SupabaseFoodSearchService()

    var body: some View {
        NavigationStack {
            Group {
                let q = query.trimmingCharacters(in: .whitespaces)
                if q.isEmpty {
                    promptView
                } else if !results.isEmpty {
                    resultsList
                } else if isSearching {
                    loadingView
                } else if !hasSearchedCurrentQuery {
                    // User is still typing — suggestion panel floats over this.
                    // Don't show "No results" until a search has actually been committed.
                    Color.clear
                } else {
                    noResultsView
                }
            }
            .overlay(alignment: .top) {
                // Always in the view tree so text is pre-measured at opacity 0.
                // NO .animation() modifier here — animation is scoped to
                // `withAnimation` at the state-change sites so it never bleeds
                // into ForEach child content (which caused the blank-text glitch).
                suggestionPanelView
                    .opacity(showSuggestionPanel ? 1 : 0)
                    .offset(y: showSuggestionPanel ? 0 : -8)
                    .allowsHitTesting(showSuggestionPanel)
                    .accessibilityHidden(!showSuggestionPanel)
            }
            .navigationTitle("Search")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search food..."
            )
            .onSubmit(of: .search) {
                commitSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan barcode")
                }
            }
            .navigationDestination(item: $scannedFood) { food in
                FoodDetailView(food: food, initialQuantity: logStore.lastQuantity(for: food) ?? 1.0)
            }
            .fullScreenCover(isPresented: $showScanner, onDismiss: {
                // Promote the pending food to scannedFood only after the cover
                // has fully dismissed, keeping the navigation push clean.
                scannedFood = pendingScannedFood
                pendingScannedFood = nil
            }) {
                BarcodeScannerView { food in
                    pendingScannedFood = food
                }
            }
            .onChange(of: query) {
                // If a search was just committed (suggestion tap), the query
                // change is programmatic — skip suggestion logic entirely.
                if hasCommitted {
                    hasCommitted = false
                    return
                }
                let q = query.trimmingCharacters(in: .whitespaces)
                // User is typing — clear stale results and cancel any in-flight search.
                // This keeps the suggestion panel as the sole UI while typing.
                results = []
                isSearching = false
                hasSearchedCurrentQuery = false
                searchTask?.cancel()
                // Update suggestions (content OUTSIDE withAnimation to avoid text crossfade).
                displayedSuggestions = matchingSuggestions(for: q)
                let wantPanel = !q.isEmpty && !displayedSuggestions.isEmpty
                if wantPanel != showSuggestionPanel {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showSuggestionPanel = wantPanel
                    }
                }
            }
            .onChange(of: typeAheadTerms) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty, !hasCommitted else { return }
                displayedSuggestions = matchingSuggestions(for: q)
                let wantPanel = !displayedSuggestions.isEmpty && !hasSearchedCurrentQuery
                if wantPanel != showSuggestionPanel {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showSuggestionPanel = wantPanel
                    }
                }
            }
            .onChange(of: logStore.lastLoggedEntry?.id) { _, newId in
                guard newId != nil else { return }
                let captured = logStore.lastLoggedEntry
                logStore.clearLastLog()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    bannerEntry = captured
                }
                autoDismissTask?.cancel()
                autoDismissTask = Task {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        bannerEntry = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if bannerEntry != nil {
                    logBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task {
                // Fetch suggestions, type-ahead terms, recents, favorites, and grocery items concurrently.
                async let fetchedSuggestions = suggestionService.fetchSuggestions()
                async let fetchedTerms = suggestionService.fetchTypeAheadTerms()
                if let userId = authManager.currentUserId {
                    async let recents: Void = logStore.refreshRecents(userId: userId)
                    async let favs: Void    = favStore.refresh(userId: userId)
                    async let grocery: Void = groceryStore.fetchItems(userId: userId)
                    _ = await (recents, favs, grocery)
                }
                suggestions = await fetchedSuggestions
                typeAheadTerms = await fetchedTerms
            }
            // Receives food items resolved by the center nav scan button (in MainTabView).
            // The cover has already dismissed before this fires, so we can push directly.
            .onChange(of: router.pendingScannedItem) { _, newItem in
                guard let item = newItem else { return }
                router.pendingScannedItem = nil
                scannedFood = item
            }
        }
    }

    // MARK: - Daily summary

    /// Computes today's remaining calories and macros from in-memory data.
    /// Returns `nil` when no active goal is set (pre-onboarding users).
    /// Same logic as `DashboardView` — both read from the same shared stores.
    private var daySummary: DaySummary? {
        guard let goal = authManager.goal else { return nil }
        var s = DaySummary.from(goal: goal)
        for log in logStore.todayLogs {
            s.consumedCalories += log.calories
            s.consumedProteinG += Int(log.proteinG.rounded())
            s.consumedCarbsG   += Int(log.carbsG.rounded())
            s.consumedFatG     += Int(log.fatG.rounded())
        }
        return s
    }

    /// A List-compatible section that renders `SearchDaySummaryCard` if the
    /// day summary is available. Inserted at the top of `promptView` and
    /// `resultsList` so the remaining budget is always visible.
    @ViewBuilder
    private var summarySection: some View {
        if let summary = daySummary {
            Section {
                SearchDaySummaryCard(summary: summary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    // MARK: - View states

    /// Shown when the search field is empty.
    /// Order: summary → Favorites → Recent → Grocery List → Suggestions.
    private var promptView: some View {
        List {
            summarySection
            if !favStore.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favStore.favorites) { fav in
                        favoriteFoodLink(fav)
                    }
                }
            }
            if !logStore.recentFoods.isEmpty {
                Section("Recent") {
                    ForEach(logStore.recentFoods) { log in
                        recentFoodLink(log)
                    }
                }
            }
            groceryListSection
            if !suggestions.isEmpty {
                Section("Suggestions") {
                    ForEach(suggestions) { food in
                        foodLink(food)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Grocery list section

    /// Always-visible section in the empty state for the user's grocery list.
    /// Shows checked items with a strikethrough. "Clear checked" appears in the
    /// header when at least one item is checked.
    @ViewBuilder
    private var groceryListSection: some View {
        Section {
            ForEach(groceryStore.items) { item in
                GroceryItemRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let userId = authManager.currentUserId else { return }
                        Task { await groceryStore.toggleItem(item, userId: userId) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            guard let userId = authManager.currentUserId else { return }
                            Task { await groceryStore.deleteItem(item, userId: userId) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            // Add-item row: text field + inline confirm button.
            HStack(spacing: 8) {
                TextField("Add item…", text: $newGroceryItem)
                    .onSubmit { addGroceryItem() }
                if !newGroceryItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: addGroceryItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Grocery List")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                if groceryStore.items.contains(where: \.isChecked) {
                    Button("Clear checked") {
                        guard let userId = authManager.currentUserId else { return }
                        Task { await groceryStore.clearChecked(userId: userId) }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
            .padding(.bottom, 2)
        }
    }

    /// Adds the current `newGroceryItem` text as a new list entry, then clears the field.
    private func addGroceryItem() {
        let name = newGroceryItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let userId = authManager.currentUserId else { return }
        newGroceryItem = ""
        Task { await groceryStore.addItem(name: name, userId: userId) }
    }

    /// Shown while a debounce delay or network request is in progress and
    /// there are no stale results to display.
    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
            Text("Searching…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color(.systemGray3))
                .padding(.bottom, 4)
            Text("No results for \"\(query.trimmingCharacters(in: .whitespaces))\"")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try a different name or category.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    private var resultsList: some View {
        List {
            summarySection
            Section("\(results.count) result\(results.count == 1 ? "" : "s")") {
                ForEach(results) { food in
                    foodLink(food)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Shared food row + navigation

    @ViewBuilder
    private func foodLink(_ food: FoodItem) -> some View {
        NavigationLink {
            FoodDetailView(food: food, initialQuantity: logStore.lastQuantity(for: food) ?? 1.0)
        } label: {
            FoodRow(food: food)
        }
    }

    /// A Favorite-specific row that wraps `foodLink` with a leading swipe action.
    /// Quantity uses `logStore.lastQuantity` when the food has been logged before;
    /// falls back to 1.0 for foods with no log history.
    ///
    /// Tap → `FoodDetailView` (unchanged). Swipe right → `quickLog` fires.
    @ViewBuilder
    private func favoriteFoodLink(_ fav: FavoriteFood) -> some View {
        foodLink(fav.asFoodItem())
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    quickLog(fav)
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                }
                .tint(.green)
            }
    }

    /// A Recent-specific row that wraps `foodLink` with a leading swipe action
    /// for one-gesture quick-logging at the food's previously used quantity.
    ///
    /// Tap → `FoodDetailView` (unchanged). Swipe right → `quickLog` fires.
    @ViewBuilder
    private func recentFoodLink(_ log: FoodLog) -> some View {
        foodLink(log.asFoodItem())
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    quickLog(log)
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                }
                .tint(.green)
            }
    }

    /// Logs a favorite at the last-used quantity for that food, or 1.0 if no
    /// history exists. Favorites store per-serving nutrition — `lastQuantity`
    /// supplies the repeat-use multiplier from `recentFoods`.
    private func quickLog(_ fav: FavoriteFood) {
        guard !isQuickLogging, let userId = authManager.currentUserId else { return }
        let food = fav.asFoodItem()
        let qty  = logStore.lastQuantity(for: food) ?? 1.0
        isQuickLogging = true
        Task {
            defer { isQuickLogging = false }
            try? await logStore.insert(food: food, quantity: qty, mealSlot: .inferred(), for: userId)
            if let entry = logStore.lastLoggedEntry {
                await healthKit.exportFoodLog(entry)
            }
            notifications.cancelTodayReminder()
        }
    }

    /// Logs `log` at its stored quantity without opening `FoodDetailView`.
    /// The existing `onChange(of: logStore.lastLoggedEntry?.id)` handler
    /// fires the banner + Undo automatically — no extra wiring needed here.
    /// Meal slot is inferred from the current time (not copied from the
    /// original log) since the user is logging this food right now.
    private func quickLog(_ log: FoodLog) {
        guard !isQuickLogging, let userId = authManager.currentUserId else { return }
        isQuickLogging = true
        Task {
            defer { isQuickLogging = false }
            try? await logStore.insert(
                food:     log.asFoodItem(),
                quantity: log.quantity,
                mealSlot: .inferred(),
                for:      userId
            )
            if let entry = logStore.lastLoggedEntry {
                await healthKit.exportFoodLog(entry)
            }
            notifications.cancelTodayReminder()
        }
    }

    // MARK: - Post-log banner

    private var logBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body.weight(.medium))
            // Show the logged food name for immediate confirmation context.
            // Falls back to generic label if bannerEntry is somehow nil.
            Text(bannerEntry.map { "Logged · \($0.foodName)" } ?? "Food logged")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("View") { dismissBanner(navigateToDashboard: true) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(UIColor.systemBackground))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary)
                .clipShape(Capsule())
            Button("Undo") { undoLastLog() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func dismissBanner(navigateToDashboard: Bool = false) {
        autoDismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            bannerEntry = nil
        }
        if navigateToDashboard {
            router.selectedTab = .dashboard
        }
    }

    private func undoLastLog() {
        guard let entry = bannerEntry else { return }
        autoDismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            bannerEntry = nil
        }
        Task { try? await logStore.delete(logId: entry.id) }
    }

    // MARK: - Type-ahead suggestions

    /// Floating panel of type-ahead suggestions. Positioned via `.overlay`
    /// at the top of the content area, just below the search bar. Uses a
    /// material background and shadow for a pop-up feel without relying on
    /// the buggy system `.searchSuggestions` overlay.
    ///
    /// Reads from `displayedSuggestions` (a stable `@State` snapshot) rather
    /// than recomputing matches, so the ForEach content never shifts during
    /// the show/hide animation.
    private var suggestionPanelView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(displayedSuggestions.indices, id: \.self) { i in
                Button {
                    hasCommitted = true
                    query = displayedSuggestions[i]
                    commitSearch()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Text(displayedSuggestions[i])
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < displayedSuggestions.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// Builds a pool of suggestion terms from database food names/brands,
    /// recent logs, and favorites. Every term is guaranteed searchable.
    private var suggestionPool: [String] {
        var pool = Set<String>()
        for term in typeAheadTerms { pool.insert(term) }
        for log  in logStore.recentFoods { pool.insert(log.foodName) }
        for fav  in favStore.favorites   { pool.insert(fav.foodName) }
        return pool.sorted()
    }

    /// Returns up to 6 suggestion terms that match `query`, ranked by
    /// match quality (prefix hits first, word-prefix hits next, then shorter
    /// names). Supports multi-word queries: every query word must appear
    /// somewhere in the normalized food name so "greek van" matches
    /// "Greek Yogurt, Vanilla" and "chick sand" matches
    /// "Chick-fil-A Chicken Sandwich".
    private func matchingSuggestions(for query: String) -> [String] {
        let normalized = SupabaseFoodSearchService.normalizeForSearch(query)
        guard normalized.count >= 1 else { return [] }

        let words = normalized.split(separator: " ").map(String.init)

        return suggestionPool
            .filter { term in
                let n = SupabaseFoodSearchService.normalizeForSearch(term)
                return words.allSatisfy { n.contains($0) }
            }
            .sorted { a, b in
                let sa = SupabaseFoodSearchService.matchScore(name: a, query: normalized)
                let sb = SupabaseFoodSearchService.matchScore(name: b, query: normalized)
                if sa != sb { return sa < sb }
                return a.count < b.count
            }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Search logic

    /// Commits a search for the current query. Called only on explicit user
    /// intent: tapping a suggestion or pressing the keyboard Search button.
    /// No debounce — the user has already finished typing.
    private func commitSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        // Hide suggestions immediately — results are taking over.
        withAnimation(.easeOut(duration: 0.15)) {
            showSuggestionPanel = false
        }
        hasSearchedCurrentQuery = true
        isSearching = true
        searchTask = Task {
            let found = await searchService.search(query: q)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}

// MARK: - Grocery item row

/// A single row in the grocery list section.
/// Checkbox icon reflects checked state; text uses strikethrough + secondary colour when checked.
private struct GroceryItemRow: View {
    let item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isChecked ? Color.green : Color(.systemGray3))
                .font(.body)
                .animation(.easeInOut(duration: 0.15), value: item.isChecked)

            Text(item.name)
                .font(.body)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
                .strikethrough(item.isChecked, color: .secondary)
                .animation(.easeInOut(duration: 0.15), value: item.isChecked)

            Spacer()
        }
    }
}

// MARK: - Food row

private struct FoodRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name + calorie count on the same line
            HStack(alignment: .firstTextBaseline) {
                Text(food.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(food.calories)")
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Brand + serving size
            HStack(spacing: 4) {
                if let brand = food.brandOrCategory {
                    Text(brand)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text(food.servingSize)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Compact macro line
            MacroLine(food: food)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Macro line

private struct MacroLine: View {
    let food: FoodItem

    var body: some View {
        HStack(spacing: 10) {
            macroChip(initial: "P", value: food.proteinG, color: .red)
            macroChip(initial: "C", value: food.carbsG,   color: .orange)
            macroChip(initial: "F", value: food.fatG,     color: .blue)
        }
        .font(.caption)
    }

    private func macroChip(initial: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(initial)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(macroFormatted(value))
                .foregroundStyle(.secondary)
        }
    }

    /// Integer grams for values ≥ 10 or exact whole numbers; one decimal otherwise.
    private func macroFormatted(_ value: Double) -> String {
        if value >= 10 || value == value.rounded(.toNearestOrAwayFromZero) {
            return "\(Int(value.rounded()))g"
        }
        return String(format: "%.1fg", value)
    }
}

// MARK: - Daily summary card

/// Compact remaining-budget card shown at the top of the Search screen.
///
/// Left side: calories remaining (prominent). Right side: P / C / F
/// remaining in grams. All values animate live as food is logged.
/// The card is read-only — no tap action.
private struct SearchDaySummaryCard: View {
    let summary: DaySummary

    var body: some View {
        HStack(alignment: .center) {
            // Calories remaining — the primary decision signal
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(summary.remainingCalories)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: summary.remainingCalories)
                Text("kcal left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Macro remaining chips — P / C / F
            HStack(spacing: 10) {
                macroChip("P", value: summary.remainingProteinG, color: .red)
                macroChip("C", value: summary.remainingCarbsG,   color: .orange)
                macroChip("F", value: summary.remainingFatG,     color: .blue)
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroChip(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("\(value)g")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
    }
}

// MARK: - Preview helpers

private extension SearchView {
    /// An `AuthManager` with a fat-loss goal for use in `#Preview` blocks.
    static var previewAuth: AuthManager {
        let uid  = UUID()
        let auth = AuthManager(previewMode: true)
        auth.markOnboarded(
            goal: UserGoal(
                id: UUID(), userId: uid, goalType: .fatLoss,
                targetWeight: nil, targetPace: .moderate,
                dailyCalories: 2100, dailyProtein: 165,
                dailyCarbs: 220, dailyFat: 65,
                createdAt: Date(), updatedAt: Date()
            ),
            profile: UserProfile(
                id: UUID(), displayName: nil,
                heightCm: nil, weightKg: nil, birthdate: nil,
                createdAt: Date(), updatedAt: Date()
            )
        )
        return auth
    }

    /// A `FoodLogStore` pre-seeded with today's logs (522 kcal consumed)
    /// and recents for the "With recents + summary" preview.
    static var previewLogStore: FoodLogStore {
        let uid = UUID()
        let todayLogs: [FoodLog] = [
            FoodLog(id: UUID(), userId: uid, foodName: "Oats, rolled",
                    servingLabel: "40g (half cup)", quantity: 1.0,
                    calories: 154, proteinG: 5.4, carbsG: 26.0, fatG: 2.8,
                    mealSlot: .breakfast, loggedAt: Date(), createdAt: Date()),
            FoodLog(id: UUID(), userId: uid, foodName: "Whey Protein",
                    servingLabel: "1 scoop (30g)", quantity: 1.0,
                    calories: 120, proteinG: 24.0, carbsG: 3.0, fatG: 1.5,
                    mealSlot: .snack, loggedAt: Date(), createdAt: Date()),
            FoodLog(id: UUID(), userId: uid, foodName: "Chicken Breast, cooked",
                    servingLabel: "100g", quantity: 1.5,
                    calories: 248, proteinG: 46.5, carbsG: 0.0, fatG: 5.4,
                    mealSlot: .lunch, loggedAt: Date(), createdAt: Date()),
        ]
        let recents: [FoodLog] = todayLogs
        return FoodLogStore(previewLogs: todayLogs, previewRecents: recents)
    }
}

// MARK: - Preview

#Preview("No recents") {
    SearchView()
        .environment(FoodLogStore())
        .environment(FavoriteFoodStore())
        .environment(GroceryListStore())
        .environment(AuthManager(previewMode: true))
        .environment(HealthKitService())
        .environment(NotificationService())
        .environment(AppRouter())
}

#Preview("With recents + summary") {
    SearchView()
        .environment(SearchView.previewLogStore)
        .environment(FavoriteFoodStore())
        .environment(GroceryListStore())
        .environment(SearchView.previewAuth)
        .environment(HealthKitService())
        .environment(NotificationService())
        .environment(AppRouter())
}
