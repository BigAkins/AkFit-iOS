import SwiftUI

@main
struct AkFitApp: App {
    @State private var authManager = AuthManager()
    @State private var logStore    = FoodLogStore()
    @State private var router      = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(logStore)
                .environment(router)
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
