import Foundation
import Supabase

/// Owns all authentication state for the app.
///
/// Routing logic in `RootView` reads `isAuthenticated` and `isOnboarded` to
/// decide which top-level screen to show. Both are derived from the session
/// and goal state managed here.
///
/// State is sourced exclusively from the `authStateChanges` async stream —
/// no manual session fetches. On every sign-in event the active goal is
/// fetched; its presence determines whether onboarding is complete.
///
/// ## Routing guarantee
/// For `.initialSession` and `.signedIn` events, `session`, `profile`, and
/// `goal` are all set in one synchronous block after `fetchUserData` completes.
/// This prevents `RootView` from flashing `OnboardingView` for an already-
/// onboarded user during sign-in.
@Observable
final class AuthManager {

    // MARK: - Public state

    /// The live Supabase session. `nil` when signed out.
    private(set) var session: Session?

    /// The user's profile row. Set after sign-in; `nil` when signed out.
    private(set) var profile: UserProfile?

    /// The user's active goal. Presence indicates onboarding is complete.
    private(set) var goal: UserGoal?

    /// `true` while the initial auth-state check is in progress.
    /// Prevents a flash of the auth screen on cold start for returning users.
    private(set) var isLoading: Bool = true

    // MARK: - Derived state

    var isAuthenticated: Bool { session != nil }

    /// `true` when the user has completed onboarding (has an active goal).
    var isOnboarded: Bool { goal != nil }

    /// The authenticated user's email address. `nil` when signed out.
    /// Use this instead of accessing `session.user.email` directly in views,
    /// so views don't need to import Supabase's Auth module.
    var currentUserEmail: String? { session?.user.email }

    /// The authenticated user's UUID. `nil` when signed out.
    /// Use this instead of accessing `session.user.id` directly in views,
    /// so views don't need to import Supabase's Auth module.
    var currentUserId: UUID? { session?.user.id }

    // MARK: - Init

    init() {
        Task { await startAuthObserver() }
    }

    /// Preview / test initializer. Skips the Supabase observer so no network
    /// calls are made and `isLoading` is immediately `false`.
    ///
    /// - Parameter previewMode: Pass `true` only in `#Preview` blocks or tests.
    init(previewMode: Bool) {
        guard !previewMode else {
            isLoading = false
            return
        }
        Task { await startAuthObserver() }
    }

    // MARK: - Auth state observation

    private func startAuthObserver() async {
        for await (event, session) in SupabaseClientProvider.shared.auth.authStateChanges {
            await handle(event: event, session: session)
        }
    }

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {

        case .initialSession, .signedIn:
            // Fetch user data BEFORE updating session so that `RootView` sees
            // a fully-consistent state the first time it renders after auth.
            // (Setting session first would briefly show OnboardingView even for
            // onboarded users while fetchUserData is in flight.)
            if let session {
                let (fetchedProfile, fetchedGoal) = await fetchUserData(userId: session.user.id)
                // All three properties set synchronously — no intermediate renders.
                self.profile = fetchedProfile
                self.goal    = fetchedGoal
                self.session = session
            } else {
                self.session = nil
            }

        case .tokenRefreshed, .userUpdated:
            // Token refresh doesn't change profile or goal — update session only.
            self.session = session

        case .signedOut:
            self.session = nil
            self.profile = nil
            self.goal    = nil

        default:
            // passwordRecovery, mfaChallengeVerified, etc. — no routing change.
            break
        }

        if isLoading { isLoading = false }
    }

    // MARK: - User data fetching

    /// Fetches profile and active goal concurrently.
    /// Returns `(nil, nil)` for a brand-new user with no rows yet — this is
    /// the expected "not onboarded" state, not an error.
    private func fetchUserData(userId: UUID) async -> (UserProfile?, UserGoal?) {
        async let profileResult = fetchProfile(userId: userId)
        async let goalResult    = fetchActiveGoal(userId: userId)
        return await (profileResult, goalResult)
    }

    private func fetchProfile(userId: UUID) async -> UserProfile? {
        do {
            return try await SupabaseClientProvider.shared
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
        } catch {
            return nil
        }
    }

    private func fetchActiveGoal(userId: UUID) async -> UserGoal? {
        do {
            return try await SupabaseClientProvider.shared
                .from("goals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value
        } catch {
            // No goal row = not yet onboarded. Expected for new users.
            return nil
        }
    }

    // MARK: - Auth actions

    /// Creates a new account. Returns `true` if email confirmation is required
    /// (Supabase project has "Confirm email" enabled), `false` if the user is
    /// signed in immediately (auto-confirm is on).
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await SupabaseClientProvider.shared.auth.signUp(
            email: email,
            password: password
        )
        // When confirmation is required, `response.session` is nil and the
        // authStateChanges stream will fire only after the user clicks the link.
        return response.session == nil
    }

    /// Signs in with email and password. Throws `AuthError` on failure.
    /// Session and user data are updated via the `authStateChanges` observer.
    func signIn(email: String, password: String) async throws {
        try await SupabaseClientProvider.shared.auth.signIn(
            email: email,
            password: password
        )
    }

    /// Signs out the current user. All local state is cleared by the observer.
    func signOut() async throws {
        try await SupabaseClientProvider.shared.auth.signOut()
    }

    /// Sends a password reset email to the given address.
    ///
    /// On success, Supabase emails a link the user can use to set a new password.
    /// The link opens the Supabase project's hosted reset page — no custom URL
    /// scheme is required for TestFlight.
    func sendPasswordReset(email: String) async throws {
        try await SupabaseClientProvider.shared.auth.resetPasswordForEmail(email)
    }

    /// Signs in via Apple ID credential.
    ///
    /// Called by `AuthView` after a successful Sign in with Apple presentation.
    /// `rawNonce` is the original un-hashed nonce — Supabase re-hashes it to verify
    /// against the `nonce` claim Apple embedded in the identity token JWT.
    ///
    /// Session and user data are updated via the `authStateChanges` observer,
    /// so routing to onboarding or the main app happens automatically.
    func signInWithApple(idToken: String, rawNonce: String) async throws {
        try await SupabaseClientProvider.shared.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )
    }

    /// Signs in via Google OAuth using a PKCE flow presented inside an
    /// `ASWebAuthenticationSession` — no browser switch, no URL scheme registration
    /// in Info.plist required.
    ///
    /// Supabase's `signInWithOAuth(provider:redirectTo:)` wraps the
    /// `ASWebAuthenticationSession` and exchanges the code for a session internally.
    /// When it completes, the session is stored and `authStateChanges` emits `.signedIn`,
    /// which the observer in `startAuthObserver()` picks up to update state and let
    /// `RootView` re-route automatically.
    ///
    /// **One-time setup required (developer):**
    /// 1. Enable Google as an OAuth provider in the Supabase project dashboard
    ///    (Authentication → Providers → Google; paste the Google Cloud Console
    ///    Web Client ID and Client Secret).
    /// 2. Add `akfit://auth-callback` to the Supabase dashboard's "Redirect URLs" list
    ///    (Authentication → URL Configuration → Redirect URLs).
    func signInWithGoogle() async throws {
        try await SupabaseClientProvider.shared.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "akfit://auth-callback")!
        )
        // Session stored internally; authStateChanges fires with .signedIn.
        // RootView re-routes automatically via AuthManager state.
    }

    // MARK: - Post-onboarding

    /// Called by `OnboardingView` after persisting a new goal, so the app
    /// routes to `MainTabView` without an extra network round-trip.
    func markOnboarded(goal: UserGoal, profile: UserProfile) {
        self.goal    = goal
        self.profile = profile
    }

    /// Called by `EditGoalView` after the user saves updated targets.
    /// Updates the in-memory goal so all views (dashboard, progress tab)
    /// immediately reflect the new targets without a full re-fetch.
    func updateGoal(_ goal: UserGoal) {
        self.goal = goal
    }

    /// Called after body-stat edits to keep the in-memory profile in sync.
    func updateProfile(_ profile: UserProfile) {
        self.profile = profile
    }
}
