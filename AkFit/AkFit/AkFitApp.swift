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
///   isLoading                            → blank (prevents auth-screen flash on cold start)
///   !isAuthenticated                     → AuthView
///   isAuthenticated && dataFetchFailed   → DataFetchErrorView (retry screen)
///   !isOnboarded                         → OnboardingView
///   default                              → MainTabView
private struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            } else if !authManager.isAuthenticated {
                AuthView()
            } else if authManager.dataFetchFailed {
                DataFetchErrorView()
            } else if !authManager.isOnboarded {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.isLoading)
        .animation(.easeInOut(duration: 0.25), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: authManager.isOnboarded)
        .animation(.easeInOut(duration: 0.25), value: authManager.dataFetchFailed)
    }
}

// MARK: - Data fetch error screen

/// Shown when the user is authenticated but their profile/goal could not be
/// loaded due to a network or backend error.
///
/// Displayed instead of `OnboardingView` to prevent a returning user from
/// accidentally overwriting their existing data.
private struct DataFetchErrorView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Couldn't load your data")
                    .font(.system(size: 24, weight: .bold))

                Text("Check your connection and try again.\nYour progress is safe.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRetrying = true
                    Task {
                        defer { isRetrying = false }
                        await authManager.retryFetchUserData()
                    }
                } label: {
                    Group {
                        if isRetrying {
                            ProgressView()
                                .tint(Color(UIColor.systemBackground))
                        } else {
                            Text("Try Again")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .background(Color.primary)
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isRetrying)

                Button("Sign Out") {
                    Task { try? await authManager.signOut() }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
        .background(Color(UIColor.systemBackground))
    }
}
