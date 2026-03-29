import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }

            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    // AuthManager needs a goal so DashboardView renders targets, not a blank screen.
    // FoodLogStore is required by DashboardView and FoodDetailView (via SearchView).
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
    return MainTabView()
        .environment(auth)
        .environment(FoodLogStore())
}
