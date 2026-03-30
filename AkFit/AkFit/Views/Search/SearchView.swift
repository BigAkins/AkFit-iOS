import SwiftUI

/// Food search screen — the entry point for the logging loop.
///
/// Reachable directly via the Search tab or by tapping the dashboard FAB
/// (which sets `AppRouter.selectedTab = .search`).
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

    @Environment(FoodLogStore.self) private var logStore
    @Environment(AuthManager.self)  private var authManager

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
                FoodDetailView(food: food)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { food in
                    scannedFood = food
                }
            }
            .onChange(of: query) { performSearch() }
            .task {
                // Fetch suggestions and recent foods concurrently on first appear.
                async let fetchedSuggestions = suggestionService.fetchSuggestions()
                if let userId = authManager.currentUserId {
                    await logStore.refreshRecents(userId: userId)
                }
                suggestions = await fetchedSuggestions
            }
        }
    }

    // MARK: - View states

    /// Shown when the search field is empty.
    /// "Recent" section appears above "Suggestions" when the user has prior logs.
    private var promptView: some View {
        List {
            if !logStore.recentFoods.isEmpty {
                Section("Recent") {
                    ForEach(logStore.recentFoods) { log in
                        foodLink(log.asFoodItem())
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
            FoodDetailView(food: food)
        } label: {
            FoodRow(food: food)
        }
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

// MARK: - Preview

#Preview("No recents") {
    SearchView()
        .environment(FoodLogStore())
        .environment(AuthManager(previewMode: true))
}

#Preview("With recents") {
    let uid = UUID()
    let recents: [FoodLog] = [
        FoodLog(id: UUID(), userId: uid, foodName: "Chicken Breast, cooked",
                servingLabel: "100g", quantity: 1.5,
                calories: 248, proteinG: 46.5, carbsG: 0, fatG: 5.4,
                loggedAt: Date(), createdAt: Date()),
        FoodLog(id: UUID(), userId: uid, foodName: "Oats, rolled",
                servingLabel: "40g (½ cup)", quantity: 1.0,
                calories: 154, proteinG: 5.4, carbsG: 26, fatG: 2.8,
                loggedAt: Date(), createdAt: Date()),
        FoodLog(id: UUID(), userId: uid, foodName: "Whey Protein",
                servingLabel: "1 scoop (30g)", quantity: 1.0,
                calories: 120, proteinG: 24, carbsG: 3.0, fatG: 1.5,
                loggedAt: Date(), createdAt: Date()),
    ]
    SearchView()
        .environment(FoodLogStore(previewRecents: recents))
        .environment(AuthManager(previewMode: true))
}
