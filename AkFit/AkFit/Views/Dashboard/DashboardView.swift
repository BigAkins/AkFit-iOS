import SwiftUI

/// Main dashboard — the first screen the user sees after onboarding.
///
/// Data is sourced entirely from `AuthManager.goal` (already in memory).
/// No network fetch is triggered here. When food logging is added, populate
/// `DaySummary.consumed*` fields from today's log entries and this view
/// will reflect the correct remaining values automatically.
struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showAddSheet = false

    /// Derived synchronously from the in-memory goal — no async work.
    private var summary: DaySummary? {
        authManager.goal.map { DaySummary.from(goal: $0) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                ScrollView {
                    if let summary {
                        VStack(spacing: 16) {
                            CalorieSummaryCard(summary: summary)
                            MacroRow(summary: summary)
                            FoodLogSection()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 96) // clearance above tab bar + FAB
                    }
                }
                .navigationTitle("Today")
            }

            // Floating add button — entry point for food logging
            Button {
                showAddSheet = true
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
        .sheet(isPresented: $showAddSheet) {
            AddFoodPlaceholder()
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

            Text(name)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text("remaining")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Mini progress ring — centered below the text
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's food")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Empty state — replaced by actual log entries when logging is built.
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
}

// MARK: - Progress ring

/// Circular arc progress indicator. Track is a faint tint; progress arc grows clockwise.
/// Used at two sizes: 80pt (calorie card) and 36pt (macro cards).
private struct ProgressRing: View {
    let progress: Double  // 0.0 – 1.0
    let color: Color
    var size: CGFloat   = 80
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

// MARK: - Add food placeholder sheet

/// Placeholder presented by the FAB until food search / logging is implemented.
private struct AddFoodPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color(.systemGray3))
                .padding(.bottom, 12)

            Text("Food search coming soon")
                .font(.headline)

            Text("This will open food search and logging.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 4)

            Spacer()
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    let auth = AuthManager(previewMode: true)
    auth.markOnboarded(
        goal: UserGoal(
            id: UUID(),
            userId: UUID(),
            goalType: .fatLoss,
            targetCalories: 2100,
            targetProteinG: 165,
            targetCarbsG: 220,
            targetFatG: 65,
            heightCm: nil,
            weightKg: nil,
            age: nil,
            sex: nil,
            activityLevel: nil,
            pace: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        profile: UserProfile(id: UUID(), displayName: nil, createdAt: Date())
    )
    return DashboardView()
        .environment(auth)
}
