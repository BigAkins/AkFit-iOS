import Foundation
import Supabase

/// Owns all authentication state for the app.
///
/// Routing logic in `RootView` reads `isAuthenticated`, `isOnboarded`, and
/// `dataFetchFailed` to decide which top-level screen to show. All are derived
/// from the session and goal state managed here.
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
///
/// ## Network failure safety
/// `fetchActiveGoal` and `fetchProfile` distinguish between Supabase's
/// "row not found" response (PGRST116 — expected for new users) and all other
/// errors (network failures, timeouts, unexpected backend errors). Only a true
/// "not found" response returns `nil`; any other failure sets `dataFetchFailed`
/// so `RootView` can surface a retry screen instead of routing to `OnboardingView`.
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

    /// `true` when a network or backend error prevented user data from loading.
    /// Cleared on successful fetch or sign-out.
    /// `RootView` shows a retry screen instead of `OnboardingView` when this is set.
    private(set) var dataFetchFailed: Bool = false

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
                let result = await fetchUserData(userId: session.user.id)
                // All properties set synchronously — no intermediate renders.
                self.profile         = result.profile
                self.goal            = result.goal
                self.dataFetchFailed = result.fetchFailed
                self.session         = session
            } else {
                self.session         = nil
                self.dataFetchFailed = false
            }

        case .tokenRefreshed, .userUpdated:
            // Token refresh doesn't change profile or goal — update session only.
            self.session = session

        case .signedOut, .userDeleted:
            // userDeleted fires when the account is removed (admin-deleted or future
            // account-deletion feature). Treat it identically to sign-out so the app
            // doesn't remain in an authenticated state with a deleted session.
            self.session         = nil
            self.profile         = nil
            self.goal            = nil
            self.dataFetchFailed = false

        default:
            // passwordRecovery, mfaChallengeVerified, etc. — no routing change.
            break
        }

        if isLoading { isLoading = false }
    }

    // MARK: - User data fetching

    /// Carries the result of a concurrent profile + goal fetch.
    private struct UserDataResult {
        var profile:     UserProfile?
        var goal:        UserGoal?
        /// `true` when at least one fetch failed for a reason other than
        /// "row does not exist yet" (e.g. network timeout, unexpected backend error).
        var fetchFailed: Bool
    }

    /// Fetches profile and active goal concurrently.
    ///
    /// A Supabase "row not found" response (PGRST116) is the expected state for
    /// brand-new users and returns `nil` without setting `fetchFailed`.
    /// Any other error (network failure, timeout, unexpected backend error) sets
    /// `fetchFailed = true` so the caller can distinguish a new user from a
    /// returning user whose data could not be loaded.
    private func fetchUserData(userId: UUID) async -> UserDataResult {
        async let profileTask = fetchProfile(userId: userId)
        async let goalTask    = fetchActiveGoal(userId: userId)

        let profileResult = await profileTask
        let goalResult    = await goalTask

        let fetchFailed = profileResult.fetchFailed || goalResult.fetchFailed
        return UserDataResult(
            profile:     profileResult.value,
            goal:        goalResult.value,
            fetchFailed: fetchFailed
        )
    }

    /// Supabase PostgREST "row not found" error code returned when `.single()`
    /// finds zero matching rows. This is the expected state for new users.
    private static let postgrestNotFound = "PGRST116"

    /// Returns `true` when `error` represents a "row not found" response from
    /// Supabase PostgREST — i.e. the query succeeded but matched zero rows.
    private static func isNotFound(_ error: Error) -> Bool {
        (error as? PostgrestError)?.code == postgrestNotFound
    }

    private func fetchProfile(userId: UUID) async -> (value: UserProfile?, fetchFailed: Bool) {
        do {
            let value: UserProfile = try await SupabaseClientProvider.shared
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return (value, false)
        } catch {
            // PGRST116 = no profile row yet. Expected for brand-new users; not an error.
            if Self.isNotFound(error) { return (nil, false) }
            // Any other error (network, timeout, backend) — surface as fetch failure.
            return (nil, true)
        }
    }

    private func fetchActiveGoal(userId: UUID) async -> (value: UserGoal?, fetchFailed: Bool) {
        do {
            let value: UserGoal = try await SupabaseClientProvider.shared
                .from("goals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value
            return (value, false)
        } catch {
            // PGRST116 = no goal row yet. Expected for new users; not an error.
            if Self.isNotFound(error) { return (nil, false) }
            // Any other error — returning user whose data could not be loaded.
            return (nil, true)
        }
    }

    // MARK: - Retry after fetch failure

    /// Re-fetches profile and goal for the current session.
    ///
    /// Called from the `RootView` error screen when the user taps "Try Again"
    /// after a transient network failure prevented their data from loading.
    /// Clears `dataFetchFailed` on success; sets it again on continued failure.
    func retryFetchUserData() async {
        guard let session else { return }
        let result = await fetchUserData(userId: session.user.id)
        self.profile         = result.profile
        self.goal            = result.goal
        self.dataFetchFailed = result.fetchFailed
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
