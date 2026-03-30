import SwiftUI

/// Main dashboard — the first screen the user sees after onboarding.
///
/// **Data sources:**
/// - Targets come from `AuthManager.goal` (already in memory, no fetch).
/// - Consumed values are computed from `FoodLogStore.todayLogs`.
/// - `FoodLogStore.refreshToday` is called once on first appear via `.task`.
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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                ScrollView {
                    if let summary {
                        VStack(spacing: 16) {
                            CalorieSummaryCard(summary: summary)
                            MacroRow(summary: summary)
                            FoodLogSection(logs: logStore.todayLogs, logStore: logStore)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 96) // clearance above tab bar + FAB
                    }
                }
                .navigationTitle("Today")
                .task {
                    // Fetch today's logs once on first appear.
                    // After logging, FoodLogStore appends in memory so no re-fetch needed.
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

                Text("Calories remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer().frame(height: 2)

                Text("of \(summary.targetCalories) target")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                remaining: summary.remainingProteinG,
                target: summary.targetProteinG,
                progress: summary.proteinProgress,
                color: .red
            )
            MacroCard(
                name: "Carbs",
                remaining: summary.remainingCarbsG,
                target: summary.targetCarbsG,
                progress: summary.carbsProgress,
                color: .orange
            )
            MacroCard(
                name: "Fat",
                remaining: summary.remainingFatG,
                target: summary.targetFatG,
                progress: summary.fatProgress,
                color: .blue
            )
        }
    }
}

private struct MacroCard: View {
    let name: String
    let remaining: Int
    let target: Int
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(remaining)g")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: remaining)

            Text(name)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text("remaining")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ProgressRing(progress: progress, color: color, size: 36, lineWidth: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Food log section

private struct FoodLogSection: View {
    let logs: [FoodLog]
    let logStore: FoodLogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's food")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if logs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
    }

    private var emptyState: some View {
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

    private var logList: some View {
        VStack(spacing: 0) {
            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                FoodLogRow(log: log)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { try? await logStore.delete(logId: log.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                if index < logs.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Food log row

private struct FoodLogRow: View {
    let log: FoodLog

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

                // Compact P / C / F chips — same colour scheme as search results
                HStack(spacing: 8) {
                    macroChip("P", value: log.proteinG, color: .red)
                    macroChip("C", value: log.carbsG,   color: .orange)
                    macroChip("F", value: log.fatG,     color: .blue)
                }
                .font(.caption)
                .padding(.top, 1)
            }

            Spacer()

            // Calorie count — top-aligned with the food name
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(log.calories)")
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    var size: CGFloat     = 80
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

    /// Consumed: 402 kcal · P 52g · C 26g · F 8g
    static var previewLogs: [FoodLog] {
        let uid = UUID()
        return [
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Chicken Breast, cooked", servingLabel: "100g",
                quantity: 1.5,
                calories: 248, proteinG: 46.5, carbsG: 0,  fatG: 5.4,
                loggedAt: Date(), createdAt: Date()
            ),
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Oats, rolled", servingLabel: "40g (½ cup)",
                quantity: 1.0,
                calories: 154, proteinG: 5.4,  carbsG: 26, fatG: 2.8,
                loggedAt: Date(), createdAt: Date()
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
