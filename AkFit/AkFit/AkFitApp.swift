import SwiftUI

@main
struct AkFitApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var authManager   = AuthManager()
    @State private var logStore      = FoodLogStore()
    @State private var favStore      = FavoriteFoodStore()
    @State private var weightStore   = BodyweightStore()
    @State private var router        = AppRouter()
    @State private var healthKit     = HealthKitService()
    @State private var notifications = NotificationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(logStore)
                .environment(favStore)
                .environment(weightStore)
                .environment(router)
                .environment(healthKit)
                .environment(notifications)
        }
        // Refill the 7-day notification window whenever the app comes to the
        // foreground. This keeps the rolling schedule current without any
        // background processing — the notifications themselves fire even while
        // the app is closed.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await notifications.checkAuthorization()
                if notifications.isEnabled && notifications.authStatus == .authorized {
                    await notifications.scheduleReminder()
                }
            }
        }
    }
}

// MARK: - Root routing view

/// Reads `AuthManager` state and routes to the correct top-level screen.
///
/// Routing rules:
///   isLoading          → blank (prevents auth-screen flash on cold start)
///   !isAuthenticated   → AuthView
///   !isOnboarded       → OnboardingView
///   default            → MainTabView
private struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            } else if !authManager.isAuthenticated {
                AuthView()
            } else if !authManager.isOnboarded {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.isLoading)
        .animation(.easeInOut(duration: 0.25), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: authManager.isOnboarded)
    }
}
