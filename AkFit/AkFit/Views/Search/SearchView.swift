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
    /// The log entry currently shown in the confirmation banner. Nil hides the banner.
    @State private var bannerEntry: FoodLog? = nil
    @State private var autoDismissTask: Task<Void, Never>? = nil

    @Environment(FoodLogStore.self)      private var logStore
    @Environment(FavoriteFoodStore.self) private var favStore
    @Environment(AuthManager.self)       private var authManager
    @Environment(AppRouter.self)         private var router

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
                    // Stale results stay visible while a new debounced search is in flight.
                    resultsList
                } else if isSearching {
                    loadingView
                } else {
                    noResultsView
                }
            }
            .navigationTitle("Search")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search food..."
            )
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
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { food in
                    scannedFood = food
                }
            }
            .onChange(of: query) { performSearch() }
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
                // Fetch suggestions, recents, and favorites concurrently on first appear.
                async let fetchedSuggestions = suggestionService.fetchSuggestions()
                if let userId = authManager.currentUserId {
                    async let recents: Void = logStore.refreshRecents(userId: userId)
                    async let favs: Void    = favStore.refresh(userId: userId)
                    _ = await (recents, favs)
                }
                suggestions = await fetchedSuggestions
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
    /// "Recent" section appears above "Suggestions" when the user has prior logs.
    private var promptView: some View {
        List {
            summarySection
            if !favStore.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favStore.favorites) { fav in
                        foodLink(fav.asFoodItem())
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

    /// Shown while a debounce delay or network request is in progress and
    /// there are no stale results to display.
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
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

    /// Logs `log` at its stored quantity without opening `FoodDetailView`.
    /// The existing `onChange(of: logStore.lastLoggedEntry?.id)` handler
    /// fires the banner + Undo automatically — no extra wiring needed here.
    private func quickLog(_ log: FoodLog) {
        guard let userId = authManager.currentUserId else { return }
        Task {
            try? await logStore.insert(
                food:     log.asFoodItem(),
                quantity: log.quantity,
                for:      userId
            )
        }
    }

    // MARK: - Post-log banner

    private var logBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body.weight(.medium))
            Text("Food logged")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
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

    // MARK: - Search logic

    private func performSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            // 250 ms debounce — rapid keystrokes cancel this sleep and restart,
            // so the network hop only fires once the user pauses.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = await searchService.search(query: q)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
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
                targetCalories: 2100, targetProteinG: 165,
                targetCarbsG: 220,    targetFatG: 65,
                heightCm: nil, weightKg: nil, age: nil, sex: nil,
                activityLevel: nil, pace: nil,
                isActive: true, createdAt: Date(), updatedAt: Date()
            ),
            profile: UserProfile(id: UUID(), displayName: nil, createdAt: Date())
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
                    loggedAt: Date(), createdAt: Date()),
            FoodLog(id: UUID(), userId: uid, foodName: "Whey Protein",
                    servingLabel: "1 scoop (30g)", quantity: 1.0,
                    calories: 120, proteinG: 24.0, carbsG: 3.0, fatG: 1.5,
                    loggedAt: Date(), createdAt: Date()),
            FoodLog(id: UUID(), userId: uid, foodName: "Chicken Breast, cooked",
                    servingLabel: "100g", quantity: 1.5,
                    calories: 248, proteinG: 46.5, carbsG: 0.0, fatG: 5.4,
                    loggedAt: Date(), createdAt: Date()),
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
        .environment(AuthManager(previewMode: true))
        .environment(AppRouter())
}

#Preview("With recents + summary") {
    SearchView()
        .environment(SearchView.previewLogStore)
        .environment(FavoriteFoodStore())
        .environment(SearchView.previewAuth)
        .environment(AppRouter())
}
