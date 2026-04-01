import SwiftUI

/// Root tab container. Tab selection is driven by `AppRouter` so any child
/// view can navigate programmatically — e.g. the dashboard FAB jumps to Search.
///
/// A center scan button floats over the tab bar between the Search and Progress
/// items. Tapping it presents `BarcodeScannerView` as a full-screen cover.
/// When the scanner resolves a barcode, the app switches to the Search tab and
/// pushes `FoodDetailView` via `AppRouter.pendingScannedItem`.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    /// Drives the full-screen scanner cover presented from the center nav button.
    @State private var showScanner = false
    /// Staging area: holds the scanned food until the scanner cover fully dismisses,
    /// then routes it through `AppRouter` to `SearchView`'s navigation stack.
    @State private var pendingScannedFood: FoodItem? = nil

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
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

            // Center scan action — sits in the middle of the tab bar.
            // Tapping this is equivalent to tapping the barcode icon in the Search
            // toolbar, but reachable from any tab without switching first.
            Button {
                showScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .accessibilityLabel("Scan barcode")
        }
        .fullScreenCover(isPresented: $showScanner, onDismiss: {
            // The scanner dismisses itself after calling onFound. Promote the
            // staged food to AppRouter so SearchView's navigation stack picks it up.
            if let food = pendingScannedFood {
                pendingScannedFood = nil
                router.pendingScannedItem = food
                router.selectedTab = .search
            }
        }) {
            BarcodeScannerView { food in
                // Stage the food — the scanner will call dismiss() after this,
                // triggering onDismiss above once the cover animation completes.
                pendingScannedFood = food
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
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: 2100, dailyProtein: 165,
            dailyCarbs: 220, dailyFat: 65,
            createdAt: Date(), updatedAt: Date()
        ),
        profile: UserProfile(
            id: UUID(), displayName: nil,
            heightCm: nil, weightKg: nil, birthdate: nil,
            createdAt: Date(), updatedAt: Date()
        )
    )
    return MainTabView()
        .environment(auth)
        .environment(FoodLogStore())
        .environment(FavoriteFoodStore())
        .environment(BodyweightStore())
        .environment(AppRouter())
        .environment(HealthKitService())
        .environment(NotificationService())
}
