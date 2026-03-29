import SwiftUI

/// Root tab container. Tab selection is driven by `AppRouter` so any child
/// view can navigate programmatically — e.g. the dashboard FAB jumps to Search.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: AppTab.dashboard) {
                DashboardView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTabView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    // AuthManager needs a goal so DashboardView renders targets, not a blank screen.
    // FoodLogStore and AppRouter are required by DashboardView.
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
        .environment(AppRouter())
}
