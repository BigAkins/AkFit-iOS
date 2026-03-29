import SwiftUI

/// Food search screen — the entry point for the logging loop.
///
/// Data is sourced from `FoodSearchService`. The current implementation uses
/// a local mock dataset. Swap `searchService` for a Supabase or API-backed
/// implementation when a real food database is available.
///
/// Navigation to food detail (portion selection + logging) is wired via
/// `NavigationLink` with a placeholder destination, ready to be filled in
/// the next milestone.
struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [FoodItem] = []
    @State private var searchTask: Task<Void, Never>? = nil

    private let searchService: any FoodSearchService = MockFoodSearchService()

    /// A small hand-picked set shown when no query is typed.
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
            .onChange(of: query) { performSearch() }
        }
    }

    // MARK: - View states

    /// Shown when the search field is empty.
    /// Displays common foods so the screen is immediately useful.
    private var promptView: some View {
        List {
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
            Text("No results for "\(query.trimmingCharacters(in: .whitespaces))"")
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
        // NavigationLink is the routing hook for food detail.
        // Replace `FoodDetailPlaceholder` with the real detail view next milestone.
        NavigationLink {
            FoodDetailPlaceholder(food: food)
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

// MARK: - Food detail placeholder

/// Temporary destination for food detail navigation.
/// Replace with the real portion-selection + logging view in the next milestone.
private struct FoodDetailPlaceholder: View {
    let food: FoodItem

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 52))
                .foregroundStyle(Color(.systemGray3))
            Text(food.name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("\(food.calories) kcal · \(food.servingSize)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Portion selection and logging\ncoming in the next milestone.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Spacer()
        }
        .navigationTitle("Food Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
