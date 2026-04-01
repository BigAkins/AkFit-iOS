import Foundation
import Supabase

/// Owns all authentication and user-state for the app.
///
/// `RootView` reads `userState`, `isOnboarded`, and `dataFetchFailed` to decide
/// which top-level screen to show. The three-way `AppUserState` replaces the
/// previous `isAuthenticated` boolean so guest mode can be expressed cleanly.
///
/// ## Guest mode
/// When `userState == .guest`, profile, goal, and `currentUserId` are sourced
/// from `GuestDataStore` (UserDefaults) — no Supabase calls are made for them.
/// All stores receive the same `GuestDataStore` reference and short-circuit to
/// local reads/writes when `guestStore.isActive` is true.
///
/// ## Routing guarantee (authenticated path)
/// For `.initialSession` and `.signedIn` events, `session`, `_serverProfile`,
/// and `_serverGoal` are all set in one synchronous block after `fetchUserData`
/// completes. This prevents `RootView` from flashing `OnboardingView` for an
/// already-onboarded user during sign-in.
@Observable
final class AuthManager {

    // MARK: - Routing state

    /// Top-level user state. Drives `RootView` routing.
    private(set) var userState: AppUserState = .signedOut

    /// `true` while the initial auth-state check is in progress.
    /// Prevents a flash of the auth screen on cold start for returning users.
    private(set) var isLoading: Bool = true

    /// `true` when a network or backend error prevented user data from loading.
    /// Cleared on successful fetch or sign-out.
    /// `RootView` shows a retry screen instead of `OnboardingView` when this is set.
    private(set) var dataFetchFailed: Bool = false

    // MARK: - Session (authenticated path only)

    /// The live Supabase session. `nil` when signed out or in guest mode.
    private(set) var session: Session?

    // MARK: - Server-side user data (authenticated path)
    //
    // Prefixed with `_server` to clearly distinguish from the guest-path
    // counterparts accessed through `GuestDataStore`.

    private var _serverProfile: UserProfile?
    private var _serverGoal:    UserGoal?

    // MARK: - Guest data store

    private let guestStore: GuestDataStore

    // MARK: - Computed: profile and goal (unified for both paths)

    /// The user's profile. Sourced from `GuestDataStore` when in guest mode;
    /// from the Supabase fetch result when authenticated.
    var profile: UserProfile? {
        userState == .guest ? guestStore.profile : _serverProfile
    }

    /// The user's active goal. Presence indicates onboarding is complete.
    /// Sourced from `GuestDataStore` in guest mode; from Supabase when authenticated.
    var goal: UserGoal? {
        userState == .guest ? guestStore.goal : _serverGoal
    }

    // MARK: - Computed: identity

    /// `true` when the user has completed onboarding (has an active goal).
    /// Works identically for guest and authenticated users.
    var isOnboarded: Bool { goal != nil }

    /// `true` when the user is in guest mode.
    var isGuest: Bool { userState == .guest }

    /// The current user's UUID.
    /// Returns the stable guest UUID when in guest mode;
    /// the Supabase user ID when authenticated; `nil` when signed out.
    var currentUserId: UUID? {
        switch userState {
        case .guest:         return guestStore.guestId
        case .authenticated: return session?.user.id
        case .signedOut:     return nil
        }
    }

    /// The authenticated user's email address. `nil` in guest mode or signed out.
    var currentUserEmail: String? {
        userState == .authenticated ? session?.user.email : nil
    }

    // MARK: - Init

    /// Production initializer. Requires a shared `GuestDataStore` instance
    /// (injected from `AkFitApp.init` so stores share the same object).
    init(guestStore: GuestDataStore) {
        self.guestStore = guestStore
        // Restore guest mode that was active on last launch.
        if guestStore.isActive {
            self.userState = .guest
        }
        Task { await startAuthObserver() }
    }

    /// Preview / test initializer. Skips the Supabase observer so no network
    /// calls are made and `isLoading` is immediately `false`.
    ///
    /// - Parameter previewMode: Pass `true` only in `#Preview` blocks or tests.
    init(previewMode: Bool, guestStore: GuestDataStore = GuestDataStore()) {
        self.guestStore = guestStore
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
            if let session {
                // A real Supabase session overrides guest mode if it was active.
                if guestStore.isActive {
                    guestStore.clearAll()
                }
                let result = await fetchUserData(userId: session.user.id)
                self._serverProfile  = result.profile
                self._serverGoal     = result.goal
                self.dataFetchFailed = result.fetchFailed
                self.session         = session
                self.userState       = .authenticated
            } else {
                // No Supabase session — honour existing guest mode if active.
                self.session = nil
                if userState != .guest {
                    self.userState = .signedOut
                }
            }

        case .tokenRefreshed, .userUpdated:
            // Token refresh doesn't change profile or goal — update session only.
            self.session = session

        case .signedOut, .userDeleted:
            // Only change state if we were authenticated. Guest mode is not
            // affected by Supabase sign-out events (guests have no session).
            if userState == .authenticated {
                self.session         = nil
                self._serverProfile  = nil
                self._serverGoal     = nil
                self.dataFetchFailed = false
                self.userState       = .signedOut
            }

        default:
            // passwordRecovery, mfaChallengeVerified, etc. — no routing change.
            break
        }

        if isLoading { isLoading = false }
    }

    // MARK: - User data fetching (authenticated path)

    private struct UserDataResult {
        var profile:     UserProfile?
        var goal:        UserGoal?
        var fetchFailed: Bool
    }

    private func fetchUserData(userId: UUID) async -> UserDataResult {
        async let profileTask = fetchProfile(userId: userId)
        async let goalTask    = fetchActiveGoal(userId: userId)

        let profileResult = await profileTask
        let goalResult    = await goalTask

        return UserDataResult(
            profile:     profileResult.value,
            goal:        goalResult.value,
            fetchFailed: profileResult.fetchFailed || goalResult.fetchFailed
        )
    }

    private static let postgrestNotFound = "PGRST116"

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
            if Self.isNotFound(error) { return (nil, false) }
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
            if Self.isNotFound(error) { return (nil, false) }
            return (nil, true)
        }
    }

    // MARK: - Retry after fetch failure (authenticated path)

    func retryFetchUserData() async {
        guard let session else { return }
        let result = await fetchUserData(userId: session.user.id)
        self._serverProfile  = result.profile
        self._serverGoal     = result.goal
        self.dataFetchFailed = result.fetchFailed
    }

    // MARK: - Guest mode actions

    /// Enters guest mode. Activates `GuestDataStore` and updates routing state.
    func enterGuestMode() {
        guestStore.activate()
        userState = .guest
    }

    /// Exits guest mode and destroys all local guest data.
    ///
    /// This is destructive and irreversible. The UI must present a confirmation
    /// dialog before calling this. After this call, `userState` is `.signedOut`.
    func exitGuestMode() {
        guestStore.clearAll()
        userState = .signedOut
    }

    // MARK: - Auth actions (authenticated path)

    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await SupabaseClientProvider.shared.auth.signUp(
            email: email,
            password: password
        )
        return response.session == nil
    }

    func signIn(email: String, password: String) async throws {
        try await SupabaseClientProvider.shared.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async throws {
        try await SupabaseClientProvider.shared.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await SupabaseClientProvider.shared.auth.resetPasswordForEmail(email)
    }

    func signInWithApple(idToken: String, rawNonce: String) async throws {
        try await SupabaseClientProvider.shared.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )
    }

    func signInWithGoogle() async throws {
        try await SupabaseClientProvider.shared.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "akfit://auth-callback")!
        )
    }

    // MARK: - Post-onboarding updates

    /// Called by `OnboardingView` (results step) after the goal and profile
    /// have been persisted. Routes to `MainTabView` without an extra network
    /// round-trip. Handles both guest and authenticated paths.
    func markOnboarded(goal: UserGoal, profile: UserProfile) {
        if userState == .guest {
            guestStore.saveGoal(goal)
            guestStore.saveProfile(profile)
        } else {
            _serverGoal    = goal
            _serverProfile = profile
        }
    }

    /// Called by `EditGoalView` after the user saves updated targets.
    func updateGoal(_ goal: UserGoal) {
        if userState == .guest {
            guestStore.saveGoal(goal)
        } else {
            _serverGoal = goal
        }
    }

    /// Called after body-stat edits to keep the in-memory profile in sync.
    func updateProfile(_ profile: UserProfile) {
        if userState == .guest {
            guestStore.saveProfile(profile)
        } else {
            _serverProfile = profile
        }
    }
}
