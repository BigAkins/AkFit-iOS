import SwiftUI

/// Food detail screen — macro summary and portion selector for the selected food.
///
/// **Data flow:** `FoodItem` arrives by value from `SearchView` (or barcode scan).
/// All macro values are scaled by `quantity` entirely within this view — the
/// model is never mutated.
///
/// **Portion selection:** ±0.25 step stepper, range 0.25–10. The calorie card,
/// macro columns, and log button all update live as the user adjusts quantity.
///
/// **Logging:** tapping "Log food" calls `FoodLogStore.insert` (environment)
/// which persists to Supabase and appends to `todayLogs` in memory.
/// `DashboardView` re-renders automatically via Observation — no manual refresh needed.
struct FoodDetailView: View {
    let food: FoodItem

    @State private var quantity:  Double  = 1.0
    @State private var isLogging: Bool    = false
    @State private var logError:  String? = nil

    @Environment(FoodLogStore.self)      private var logStore
    @Environment(FavoriteFoodStore.self) private var favStore
    @Environment(AuthManager.self)       private var authManager
    @Environment(\.dismiss)              private var dismiss

    // MARK: - Scaled nutrition

    private var scaledCalories: Int    { Int((Double(food.calories) * quantity).rounded()) }
    private var scaledProteinG: Double { food.proteinG * quantity }
    private var scaledCarbsG:   Double { food.carbsG   * quantity }
    private var scaledFatG:     Double { food.fatG     * quantity }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let brand = food.brandOrCategory {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                calorieMacroCard
                portionCard
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let isFav = favStore.isFavorite(food)
                Button {
                    guard let userId = authManager.currentUserId else { return }
                    Task { try? await favStore.toggle(food: food, for: userId) }
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundStyle(isFav ? Color.yellow : Color.secondary)
                }
                .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
            }
        }
        .safeAreaInset(edge: .bottom) {
            logButton
        }
    }

    // MARK: - Calorie + macro card

    private var calorieMacroCard: some View {
        VStack(spacing: 16) {
            // Calorie row — trailing ×N badge clarifies values are for multiple servings.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(scaledCalories)")
                    .font(.system(size: 52, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: scaledCalories)
                Text("kcal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                if quantity != 1.0 {
                    Text("×\(formatQuantity(quantity))")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: quantity)
                }
            }

            Divider()

            HStack(spacing: 0) {
                macroColumn(label: "Protein", value: scaledProteinG, color: .red)
                Divider().frame(height: 36)
                macroColumn(label: "Carbs",   value: scaledCarbsG,   color: .orange)
                Divider().frame(height: 36)
                macroColumn(label: "Fat",     value: scaledFatG,     color: .blue)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroColumn(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(macroFormatted(value))
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Portion card

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Portion")
                .font(.headline)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.servingSize)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(servingSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: quantity)
                }
                Spacer()
                QuantityStepper(quantity: $quantity)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var servingSummary: String {
        if quantity == 1.0 { return "1 serving" }
        guard food.servingWeightG > 0 else {
            return "\(formatQuantity(quantity)) servings"
        }
        let totalG = Int((food.servingWeightG * quantity).rounded())
        return "\(formatQuantity(quantity)) servings · \(totalG)g total"
    }

    // MARK: - Log button

    private var logButton: some View {
        VStack(spacing: 6) {
            if let error = logError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                guard let userId = authManager.currentUserId else { return }
                isLogging = true
                logError  = nil
                Task {
                    defer { isLogging = false }
                    do {
                        try await logStore.insert(food: food, quantity: quantity, for: userId)
                        dismiss()
                    } catch {
                        logError = "Couldn't save. Please try again."
                    }
                }
            } label: {
                Group {
                    if isLogging {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color(UIColor.systemBackground))
                            Text("Logging...")
                        }
                    } else {
                        // Live calorie preview — updates as quantity changes.
                        HStack(spacing: 6) {
                            Text("Log food")
                            Text("·")
                                .opacity(0.5)
                            Text("\(scaledCalories) kcal")
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.snappy, value: scaledCalories)
                        }
                    }
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primary)
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLogging)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: -2)
                .ignoresSafeArea()
        )
    }

    // MARK: - Formatting

    /// Integer grams for values ≥ 10 or exact whole numbers; one decimal otherwise.
    private func macroFormatted(_ value: Double) -> String {
        if value >= 10 || value == value.rounded(.toNearestOrAwayFromZero) {
            return "\(Int(value.rounded()))g"
        }
        return String(format: "%.1fg", value)
    }
}

// MARK: - Quantity stepper

/// ± stepper for selecting how many servings. Step 0.25, range 0.25–10.
/// All values are exact multiples of 0.25 (1/4 is exactly representable
/// in binary floating point), so no floating-point drift occurs.
///
/// Plays a light haptic on every step change via `.sensoryFeedback`.
private struct QuantityStepper: View {
    @Binding var quantity: Double

    private let step: Double   = 0.25
    private let minQty: Double = 0.25
    private let maxQty: Double = 10.0

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus") {
                quantity = max(minQty, (quantity - step).roundedToNearest(step))
            }
            .disabled(quantity <= minQty)

            Text(formatQuantity(quantity))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 56)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .animation(.snappy, value: quantity)

            stepButton("plus") {
                quantity = min(maxQty, (quantity + step).roundedToNearest(step))
            }
            .disabled(quantity >= maxQty)
        }
        .foregroundStyle(.primary)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sensoryFeedback(.impact(weight: .light), trigger: quantity)
    }

    private func stepButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - File-private helpers

/// Formats a quantity multiplier as a minimal decimal string.
/// 1.0 → "1",  0.5 → "0.5",  1.25 → "1.25",  2.0 → "2"
private func formatQuantity(_ n: Double) -> String {
    if n == n.rounded() { return "\(Int(n))" }
    var result = String(format: "%.2f", n)
    while result.contains(".") && (result.hasSuffix("0") || result.hasSuffix(".")) {
        result.removeLast()
    }
    return result
}

private extension Double {
    func roundedToNearest(_ step: Double) -> Double {
        (self / step).rounded() * step
    }
}

// MARK: - Previews

#Preview("Default serving") {
    NavigationStack {
        FoodDetailView(food: FoodItem(
            id: UUID(),
            name: "Chicken Breast, cooked",
            brandOrCategory: "Poultry",
            servingSize: "100g",
            servingWeightG: 100,
            calories: 165,
            proteinG: 31,
            carbsG: 0,
            fatG: 3.6
        ))
    }
    .environment(FoodLogStore())
    .environment(FavoriteFoodStore())
    .environment(AuthManager(previewMode: true))
}

#Preview("High fat food") {
    NavigationStack {
        FoodDetailView(food: FoodItem(
            id: UUID(),
            name: "Peanut Butter",
            brandOrCategory: "Nuts & Seeds",
            servingSize: "2 tbsp (32g)",
            servingWeightG: 32,
            calories: 191,
            proteinG: 7.0,
            carbsG: 7.0,
            fatG: 16
        ))
    }
    .environment(FoodLogStore())
    .environment(FavoriteFoodStore())
    .environment(AuthManager(previewMode: true))
}

#Preview("Packaged / no gram weight") {
    NavigationStack {
        FoodDetailView(food: FoodItem(
            id: UUID(),
            name: "Kind Dark Chocolate Nuts & Sea Salt",
            brandOrCategory: "Kind",
            servingSize: "1 bar",
            servingWeightG: 0,
            calories: 200,
            proteinG: 6,
            carbsG: 16,
            fatG: 15
        ))
    }
    .environment(FoodLogStore())
    .environment(FavoriteFoodStore())
    .environment(AuthManager(previewMode: true))
}
