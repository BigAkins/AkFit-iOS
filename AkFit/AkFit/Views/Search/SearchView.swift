import SwiftUI

/// Food search screen — the entry point for the logging loop.
///
/// Reachable directly via the Search tab or by tapping the dashboard FAB
/// (which sets `AppRouter.selectedTab = .search`).
///
/// **Empty state:** shows a "Recent" section (last 8 distinct foods logged,
/// newest first) above a static "Common foods" fallback list. Recent foods
/// are fetched from Supabase via `FoodLogStore.refreshRecents` on first appear
/// and updated in memory after every successful log — no re-fetch needed.
///
/// **Search state:** results from `FoodSearchService` (currently mock).
/// Swap `searchService` for a real implementation when a food database is ready.
///
/// Tapping any row pushes `FoodDetailView` where the user adjusts quantity
/// and taps "Log food" to persist the entry.
struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [FoodItem] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showScanner = false
    /// Set when a barcode scan resolves to a food item. Triggers navigation to `FoodDetailView`.
    @State private var scannedFood: FoodItem? = nil

    @Environment(FoodLogStore.self) private var logStore
    @Environment(AuthManager.self)  private var authManager

    private let searchService: any FoodSearchService = HybridFoodSearchService()

    /// Static fallback list shown below recents (or alone when recents are empty).
    private let suggestions: [FoodItem] = {
        let names: Set<String> = [
            "Chicken Breast, cooked", "Greek Yogurt, plain",
            "Oats, rolled", "Egg, whole", "Whey Protein",
            "Banana", "Peanut Butter"
        ]
        return FoodItem.mockDatabase.filter { names.contains($0.name) }
    }()

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    promptView
                } else if results.isEmpty {
                    noResultsView
                } else {
                    resultsList
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
                // Fetch recent foods when the Search tab first appears.
                // After logging, FoodLogStore.insert keeps recentFoods in sync
                // in memory so no re-fetch is needed for the same session.
                if let userId = authManager.currentUserId {
                    await logStore.refreshRecents(userId: userId)
                }
            }
        }
    }

    // MARK: - View states

    /// Shown when the search field is empty.
    /// "Recent" section appears above "Common foods" when the user has prior logs.
    private var promptView: some View {
        List {
            if !logStore.recentFoods.isEmpty {
                Section("Recent") {
                    ForEach(logStore.recentFoods) { log in
                        foodLink(log.asFoodItem())
                    }
                }
            }
            Section("Common foods") {
                ForEach(suggestions) { food in
                    foodLink(food)
                }
            }
        }
        .listStyle(.insetGrouped)
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
            return
        }
        searchTask = Task {
            let found = await searchService.search(query: q)
            guard !Task.isCancelled else { return }
            results = found
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
