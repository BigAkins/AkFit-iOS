import SwiftUI

/// Food detail screen — macro summary and portion stepper for the selected food.
///
/// **Data flow:** `FoodItem` arrives by value from `SearchView`. All macro values
/// are scaled by `quantity` entirely within this view — the model is never mutated.
///
/// **Logging:** tapping "Log food" calls `FoodLogStore.insert` (environment) which
/// persists to Supabase and appends to `todayLogs` in memory. `DashboardView`
/// re-renders automatically via Observation — no manual refresh needed.
struct FoodDetailView: View {
    let food: FoodItem

    @State private var quantity:  Double  = 1.0
    @State private var isLogging: Bool    = false
    @State private var logError:  String? = nil

    @Environment(FoodLogStore.self) private var logStore
    @Environment(AuthManager.self)  private var authManager
    @Environment(\.dismiss)         private var dismiss

    // MARK: - Scaled nutrition values

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
                servingCard
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            logButton
        }
    }

    // MARK: - Calorie + macro card

    private var calorieMacroCard: some View {
        VStack(spacing: 16) {
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

    // MARK: - Serving card

    private var servingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Serving")
                .font(.headline)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.servingSize)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(servingSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        // servingWeightG is 0 for foods reconstructed from FoodLog (gram weight
        // not stored). Show just the serving count in that case.
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
                HStack(spacing: 8) {
                    if isLogging {
                        ProgressView()
                            .tint(Color(UIColor.systemBackground))
                    }
                    Text(isLogging ? "Logging..." : "Log food")
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
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 44)
                .multilineTextAlignment(.center)

            stepButton("plus") {
                quantity = min(maxQty, (quantity + step).roundedToNearest(step))
            }
            .disabled(quantity >= maxQty)
        }
        .foregroundStyle(.primary)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stepButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 40, height: 40)
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

// MARK: - Preview

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
    .environment(AuthManager(previewMode: true))
}
