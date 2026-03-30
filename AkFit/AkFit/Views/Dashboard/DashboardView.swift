import SwiftUI

/// Main dashboard — the first screen the user sees after onboarding.
///
/// **Data sources:**
/// - Targets come from `AuthManager.goal` (already in memory, no fetch).
/// - Consumed values are computed from `FoodLogStore.todayLogs`.
/// - `FoodLogStore.refreshToday` is called once on first appear via `.task`.
///
/// **Swipe-to-delete:** Food log rows live as direct children of a `List` Section.
/// SwiftUI's `.swipeActions` requires List rows — a `ScrollView + VStack` structure
/// silently discards swipe actions. The outer `List` replaces the previous
/// `ScrollView + VStack` to make this work reliably.
///
/// **FAB action:** tapping the floating + button sets `AppRouter.selectedTab = .search`,
/// switching the user directly into the Search tab to start logging.
struct DashboardView: View {
    @Environment(AuthManager.self)  private var authManager
    @Environment(FoodLogStore.self) private var logStore
    @Environment(AppRouter.self)    private var router

    /// Targets from the active goal + consumed totals from today's log entries.
    /// Computed synchronously — no async work in the view.
    private var summary: DaySummary? {
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

    /// Running calorie total shown in the food log section header.
    private var totalLoggedCalories: Int {
        logStore.todayLogs.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                List {
                    if let summary {
                        // ── Summary cards ──────────────────────────────────────────
                        // listRowBackground(Color(UIColor.systemBackground)) makes the
                        // insetGrouped section container visually invisible — the cards
                        // draw their own gray surfaces on top.
                        Section {
                            CalorieSummaryCard(summary: summary)
                                .listRowBackground(Color(UIColor.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                            MacroRow(summary: summary)
                                .listRowBackground(Color(UIColor.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        }
                        .listSectionSeparator(.hidden)

                        // ── Food log ───────────────────────────────────────────────
                        // Rows are direct List Section children, so .swipeActions
                        // works reliably. insetGrouped clips the Section to a rounded
                        // card automatically — no manual clipShape needed.
                        Section {
                            if logStore.todayLogs.isEmpty {
                                foodLogEmptyState
                                    .listRowBackground(Color(UIColor.systemBackground))
                                    .listRowSeparator(.hidden)
                            } else {
                                ForEach(logStore.todayLogs) { log in
                                    FoodLogRow(log: log)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Task { try? await logStore.delete(logId: log.id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .listRowBackground(Color(.systemGray6))
                                        // Zero row insets: the row's own .padding(.horizontal, 16)
                                        // provides content padding; the section's inset margin
                                        // provides the gap from screen edges.
                                        .listRowInsets(EdgeInsets())
                                }
                            }
                        } header: {
                            foodLogHeader
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                // Remove the default grouped background so the screen stays white/dark
                // and the summary cards' own gray surfaces are the only decoration.
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.systemBackground))
                .navigationTitle("Today")
                // Bottom inset keeps the last row visible above the tab bar + FAB.
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
                .task {
                    if let userId = authManager.currentUserId {
                        await logStore.refreshToday(userId: userId)
                    }
                }
            }

            // Floating add button — jumps directly to the Search tab.
            Button {
                router.selectedTab = .search
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .frame(width: 56, height: 56)
                    .background(Color.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Food log section header

    private var foodLogHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today's food")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if !logStore.todayLogs.isEmpty {
                Text("\(totalLoggedCalories) kcal")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: totalLoggedCalories)
            }
        }
        .textCase(nil)  // prevent the default List section header uppercase
        .padding(.bottom, 4)
    }

    // MARK: - Food log empty state

    private var foodLogEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(Color(.systemGray3))

            Text("Nothing logged yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Tap + to log your first meal")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Calorie summary card

private struct CalorieSummaryCard: View {
    let summary: DaySummary

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(summary.remainingCalories)")
                    .font(.system(size: 52, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: summary.remainingCalories)

                Text("kcal remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Consumed + goal context — surfaced so users can see
                // both "what's left" and "what I've already had" without math.
                HStack(spacing: 4) {
                    Text("\(summary.consumedCalories) consumed")
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(summary.targetCalories) goal")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            Spacer()

            ProgressRing(
                progress: summary.calorieProgress,
                color: .primary,
                size: 80,
                lineWidth: 7
            )
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Macro row

private struct MacroRow: View {
    let summary: DaySummary

    var body: some View {
        HStack(spacing: 12) {
            MacroCard(
                name: "Protein",
                consumed: summary.consumedProteinG,
                target: summary.targetProteinG,
                color: .red
            )
            MacroCard(
                name: "Carbs",
                consumed: summary.consumedCarbsG,
                target: summary.targetCarbsG,
                color: .orange
            )
            MacroCard(
                name: "Fat",
                consumed: summary.consumedFatG,
                target: summary.targetFatG,
                color: .blue
            )
        }
    }
}

/// Macro card showing remaining grams, a thin horizontal progress bar,
/// and the daily target as context.
///
/// Uses `consumed` + `target` as source of truth — `remaining` and `progress`
/// are derived internally so callers don't have to compute them twice.
private struct MacroCard: View {
    let name: String
    let consumed: Int
    let target: Int
    let color: Color

    private var remaining: Int {
        max(0, target - consumed)
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(consumed) / Double(target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)

            Text("\(remaining)g")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: remaining)

            // Thin horizontal progress bar — fill represents consumed fraction.
            // Consistent with the macro bars in ProgressTabView.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(consumed > 0 ? 1.0 : 0.0))
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)

            Text("of \(target)g")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Food log row

private struct FoodLogRow: View {
    let log: FoodLog

    /// Shared formatter — avoids allocation on every row render.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.foodName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(servingText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Compact P / C / F chips — consistent colour scheme across the app
                HStack(spacing: 8) {
                    macroChip("P", value: log.proteinG, color: .red)
                    macroChip("C", value: log.carbsG,   color: .orange)
                    macroChip("F", value: log.fatG,     color: .blue)
                }
                .font(.caption)
                .padding(.top, 1)
            }

            Spacer()

            // Calorie count + time — top-aligned with the food name.
            // The time helps users recall which meal each entry belongs to.
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(log.calories)")
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(Self.timeFormatter.string(from: log.loggedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func macroChip(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("\(Int(value.rounded()))g")
                .foregroundStyle(.secondary)
        }
    }

    private var servingText: String {
        let qty = log.quantity
        let qtyStr: String
        if qty == qty.rounded() {
            qtyStr = "\(Int(qty))"
        } else {
            var s = String(format: "%.2f", qty)
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
            qtyStr = s
        }
        return "\(qtyStr) × \(log.servingLabel)"
    }
}

// MARK: - Progress ring

/// Circular arc progress indicator. Track is a faint tint; progress arc grows clockwise.
/// Used at two sizes: 80pt (calorie card) and 36pt (macro cards).
private struct ProgressRing: View {
    let progress: Double  // 0.0 – 1.0
    let color: Color
    var size: CGFloat      = 80
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview helpers

private extension DashboardView {
    static func previewAuth() -> AuthManager {
        let auth = AuthManager(previewMode: true)
        auth.markOnboarded(
            goal: UserGoal(
                id: UUID(), userId: UUID(),
                goalType: .fatLoss,
                targetCalories: 2100, targetProteinG: 165,
                targetCarbsG: 220,   targetFatG: 65,
                heightCm: nil, weightKg: nil, age: nil, sex: nil,
                activityLevel: nil, pace: nil,
                isActive: true, createdAt: Date(), updatedAt: Date()
            ),
            profile: UserProfile(id: UUID(), displayName: nil, createdAt: Date())
        )
        return auth
    }

    /// Three realistic log entries spread across different times of day.
    /// Total: 522 kcal · P 76g · C 29g · F 10g consumed
    /// Remaining: 1578 kcal · P 89g · C 191g · F 55g
    static var previewLogs: [FoodLog] {
        let uid = UUID()
        let now = Date()
        return [
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Oats, rolled", servingLabel: "40g (½ cup)",
                quantity: 1.0,
                calories: 154, proteinG: 5.4, carbsG: 26.0, fatG: 2.8,
                loggedAt: now.addingTimeInterval(-5 * 3600),
                createdAt: now.addingTimeInterval(-5 * 3600)
            ),
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Chicken Breast, cooked", servingLabel: "100g",
                quantity: 1.5,
                calories: 248, proteinG: 46.5, carbsG: 0,   fatG: 5.4,
                loggedAt: now.addingTimeInterval(-3 * 3600),
                createdAt: now.addingTimeInterval(-3 * 3600)
            ),
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Whey Protein", servingLabel: "1 scoop (30g)",
                quantity: 1.0,
                calories: 120, proteinG: 24.0, carbsG: 3.0, fatG: 1.5,
                loggedAt: now.addingTimeInterval(-1 * 3600),
                createdAt: now.addingTimeInterval(-1 * 3600)
            ),
        ]
    }
}

// MARK: - Preview

#Preview("Populated") {
    DashboardView()
        .environment(DashboardView.previewAuth())
        .environment(FoodLogStore(previewLogs: DashboardView.previewLogs))
        .environment(AppRouter())
}

#Preview("Empty state") {
    DashboardView()
        .environment(DashboardView.previewAuth())
        .environment(FoodLogStore())
        .environment(AppRouter())
}
