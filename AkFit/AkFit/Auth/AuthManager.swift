import AuthenticationServices
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
/// from `GuestDataStore` local persistence — no Supabase calls are made for them.
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

    /// Password-recovery routing state. When active, `RootView` shows the
    /// focused set-new-password flow before normal auth/onboarding routing.
    private(set) var passwordRecoveryState: PasswordRecoveryState = .inactive

    /// Display name captured from Apple's `ASAuthorizationAppleIDCredential`.
    /// Set before the Supabase sign-in call; consumed by `OnboardingView` to
    /// skip the name step (App Store requirement: don't re-ask for Apple-provided info).
    /// `nil` when no usable name was provided or after sign-out.
    private(set) var pendingAppleDisplayName: String?

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
    private let shouldFetchServerUserData: Bool

    /// Cold-start safety timeout (see `init`). Cancelled as soon as the auth
    /// observer receives its first event so a slow `fetchUserData` can never
    /// flash `AuthView` at an already signed-in user mid-resolution.
    private var loadingTimeoutTask: Task<Void, Never>?

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

    /// `true` when the current Supabase session includes a Sign in with Apple identity.
    var requiresAppleReauthorizationForAccountDeletion: Bool {
        session?.user.hasAppleIdentity == true
    }

    /// `true` while a recovery link is being handled, the user is setting a
    /// new password, or the recovery result needs to stay on screen.
    var isPasswordRecoveryPresented: Bool {
        passwordRecoveryState != .inactive
    }

    // MARK: - Init

    /// Production initializer. Requires a shared `GuestDataStore` instance
    /// (injected from `AkFitApp.init` so stores share the same object).
    init(guestStore: GuestDataStore) {
        self.guestStore = guestStore
        self.shouldFetchServerUserData = true
        if Self.isPasswordRecoveryPending {
            self.passwordRecoveryState = .processingLink
        }
        // Restore guest mode that was active on last launch.
        if guestStore.isActive {
            self.userState = .guest
        }
        Task { await startAuthObserver() }
        // Safety timeout: if the Supabase auth stream never yields an event
        // (SDK issue, network failure at cold start), clear `isLoading` after
        // 10 seconds so the user isn't stuck on a blank screen forever.
        // The auth observer normally clears `isLoading` in < 1 second.
        // Cancelled by `handle(event:session:)` so the timeout can't expose
        // an interactive `AuthView` while a session is still being resolved.
        loadingTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            if isLoading { isLoading = false }
        }
    }

    /// Preview / test initializer. Skips the Supabase observer so no network
    /// calls are made and `isLoading` is immediately `false`.
    ///
    /// - Parameter previewMode: Pass `true` only in `#Preview` blocks or tests.
    init(previewMode: Bool, guestStore: GuestDataStore = GuestDataStore()) {
        self.guestStore = guestStore
        self.shouldFetchServerUserData = !previewMode
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

    func handle(event: AuthChangeEvent, session: Session?) async {
        // An auth event is being processed — the cold-start timeout must not
        // clear `isLoading` mid-resolution (that would show an interactive
        // `AuthView`/guest entry point while a session fetch is in flight).
        loadingTimeoutTask?.cancel()

        switch event {

        case .initialSession, .signedIn:
            if let session {
                await applyAuthenticatedSession(session)
                if Self.isPasswordRecoveryPending {
                    self.passwordRecoveryState = .ready
                }
            } else {
                // No Supabase session — honour existing guest mode if active.
                self.session = nil
                if Self.isPasswordRecoveryPending {
                    Self.clearPasswordRecoveryPersistence()
                    self.passwordRecoveryState = .invalidLink
                }
                if userState != .guest {
                    self.userState = .signedOut
                }
            }

        case .tokenRefreshed, .userUpdated:
            // Token refresh doesn't change profile or goal — update session only.
            self.session = session

        case .signedOut, .userDeleted:
            Self.clearPasswordRecoveryPersistence()
            self.passwordRecoveryState = .inactive
            // Only change state if we were authenticated. Guest mode is not
            // affected by Supabase sign-out events (guests have no session).
            if userState == .authenticated {
                self.session                 = nil
                self._serverProfile          = nil
                self._serverGoal             = nil
                self.dataFetchFailed         = false
                self.pendingAppleDisplayName = nil
                self.userState               = .signedOut
            }

        case .passwordRecovery:
            guard Self.isPasswordRecoveryPending else {
                try? await SupabaseClientProvider.shared.auth.signOut(scope: .local)
                clearAuthenticatedState()
                self.passwordRecoveryState = .invalidLink
                break
            }
            self.pendingAppleDisplayName = nil
            if let session {
                await applyAuthenticatedSession(session)
            }
            self.passwordRecoveryState = .ready

        default:
            // mfaChallengeVerified, etc. — no routing change.
            break
        }

        if isLoading { isLoading = false }
    }

    // MARK: - User data fetching (authenticated path)

    private func applyAuthenticatedSession(_ session: Session) async {
        // A real Supabase session overrides guest mode if it was active.
        if guestStore.isActive {
            guestStore.clearAll()
        }
        let result = shouldFetchServerUserData
            ? await fetchUserData(userId: session.user.id)
            : UserDataResult(profile: nil, goal: nil, fetchFailed: false)
        // Re-check after the await: the user may have tapped
        // "Continue as Guest" while fetchUserData was in flight.
        // Without this, the app lands in `.authenticated` while
        // `guestStore.isActive` stays true — and every store would
        // silently write to UserDefaults instead of Supabase.
        if guestStore.isActive {
            guestStore.clearAll()
        }
        self._serverProfile  = result.profile
        self._serverGoal     = result.goal
        self.dataFetchFailed = result.fetchFailed
        self.session         = session
        self.userState       = .authenticated
    }

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
            captureFetchFailure(error, table: "profiles")
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
            captureFetchFailure(error, table: "goals")
            return (nil, true)
        }
    }

    /// Reports a profile/goal fetch failure to Sentry (these route the user to
    /// `DataFetchErrorView`). Plain connectivity errors are skipped — they are
    /// expected on flaky networks and would only add noise.
    private func captureFetchFailure(_ error: Error, table: String) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                return
            default:
                break
            }
        }
        SentryMonitoring.captureNonFatal(
            error,
            operation: "user_data_fetch",
            tags: [
                "table":          table,
                "classification": SaveErrorClassification.classification(of: error),
                "postgrest_code": SaveErrorClassification.postgrestCode(of: error),
            ]
        )
    }

    // MARK: - Retry after fetch failure (authenticated path)

    func retryFetchUserData() async {
        guard let session else { return }
        let userId = session.user.id
        let result = await fetchUserData(userId: userId)
        guard !Task.isCancelled,
              userState == .authenticated,
              self.session?.user.id == userId
        else {
            return
        }
        self._serverProfile  = result.profile
        self._serverGoal     = result.goal
        self.dataFetchFailed = result.fetchFailed
    }

    // MARK: - Guest mode actions

    /// Enters guest mode. Activates `GuestDataStore` and updates routing state.
    func enterGuestMode() {
        pendingAppleDisplayName = nil
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

    /// Clears any Apple-only onboarding state after the user switches to a
    /// different auth path or the Apple flow fails.
    func clearPendingAppleCredentials() {
        pendingAppleDisplayName = nil
    }

    /// Clears all authenticated-session state without relying on the auth
    /// observer. Used as a last-resort fallback when sign-out can't complete.
    private func clearAuthenticatedState() {
        session                 = nil
        _serverProfile          = nil
        _serverGoal             = nil
        dataFetchFailed         = false
        pendingAppleDisplayName = nil
        if userState != .guest {
            userState = .signedOut
        }
    }

    // MARK: - Auth actions (authenticated path)

    func signUp(email: String, password: String) async throws -> Bool {
        pendingAppleDisplayName = nil
        let response = try await SupabaseClientProvider.shared.auth.signUp(
            email: email,
            password: password
        )
        return response.session == nil
    }

    func signIn(email: String, password: String) async throws {
        pendingAppleDisplayName = nil
        try await SupabaseClientProvider.shared.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async throws {
        do {
            try await SupabaseClientProvider.shared.auth.signOut()
        } catch {
            // Signing out should never trap the user in a broken authenticated
            // state. Clear the local session even if the remote revoke fails.
            clearAuthenticatedState()
        }
    }

    func sendPasswordReset(email: String) async throws {
        let state = PasswordRecoveryLink.makeState()
        Self.setExpectedPasswordRecoveryState(state)
        do {
            try await SupabaseClientProvider.shared.auth.resetPasswordForEmail(
                email,
                redirectTo: PasswordRecoveryLink.redirectURL(state: state)
            )
        } catch {
            Self.setExpectedPasswordRecoveryState(nil)
            throw error
        }
    }

    /// Handles password-recovery links opened through the app's `akfit` URL
    /// scheme. Errors intentionally remain generic so callback tokens and raw
    /// Supabase details are never displayed or logged by AkFit.
    @discardableResult
    func handleIncomingURL(_ url: URL) async -> Bool {
        guard PasswordRecoveryLink.isRecoveryURL(url) else { return false }
        guard Self.isExpectedPasswordRecoveryURL(url) else {
            Self.setPasswordRecoveryPending(false)
            passwordRecoveryState = .invalidLink
            if isLoading { isLoading = false }
            return true
        }

        passwordRecoveryState = .processingLink
        Self.setPasswordRecoveryPending(true)
        pendingAppleDisplayName = nil

        do {
            let recoveredSession = try await SupabaseClientProvider.shared.auth.session(from: url)
            Self.setExpectedPasswordRecoveryState(nil)
            await applyAuthenticatedSession(recoveredSession)
            passwordRecoveryState = .ready
        } catch {
            Self.clearPasswordRecoveryPersistence()
            passwordRecoveryState = .invalidLink
        }

        if isLoading { isLoading = false }
        return true
    }

    func updatePasswordAfterRecovery(_ password: String) async throws {
        guard passwordRecoveryState == .ready else {
            throw PasswordRecoveryError.invalidOrExpiredLink
        }

        do {
            try await SupabaseClientProvider.shared.auth.update(
                user: UserAttributes(password: password)
            )
            Self.clearPasswordRecoveryPersistence()
            passwordRecoveryState = .passwordUpdated
        } catch {
            if Self.isInvalidOrExpiredRecoveryError(error) {
                Self.clearPasswordRecoveryPersistence()
                try? await SupabaseClientProvider.shared.auth.signOut(scope: .local)
                clearAuthenticatedState()
                passwordRecoveryState = .invalidLink
                throw PasswordRecoveryError.invalidOrExpiredLink
            }
            throw PasswordRecoveryError.updateFailed
        }
    }

    func dismissPasswordRecovery() {
        guard passwordRecoveryState == .invalidLink || passwordRecoveryState == .passwordUpdated else {
            return
        }
        Self.clearPasswordRecoveryPersistence()
        passwordRecoveryState = .inactive
    }

    func cancelPasswordRecovery() async {
        passwordRecoveryState = .processingLink
        do {
            try await SupabaseClientProvider.shared.auth.signOut(scope: .local)
        } catch {
            clearAuthenticatedState()
        }
        Self.clearPasswordRecoveryPersistence()
        clearAuthenticatedState()
        passwordRecoveryState = .inactive
    }

    /// Resolves a valid authenticated session before any write to RLS-protected
    /// tables. `currentUserId` alone is not sufficient because the initial
    /// auth event can surface an expired session before token refresh completes.
    func requireAuthenticatedUserIDForWrite() async throws -> UUID {
        guard userState == .authenticated else {
            debugAuthWrite("write requested while userState=\(String(describing: userState))")
            throw AuthError.sessionMissing
        }

        var lastError: Error?

        for attempt in 1...2 {
            do {
                let validSession = try await SupabaseClientProvider.shared.auth.session
                session = validSession
                debugAuthWrite(
                    "resolved write-ready session for user \(validSession.user.id.uuidString), attempt=\(attempt), expired=\(validSession.isExpired)"
                )
                return validSession.user.id
            } catch {
                lastError = error
                debugAuthWrite(
                    "failed to resolve write-ready session on attempt \(attempt): \(Self.sanitizedAuthDebugDescription(error))"
                )
                if attempt == 1 {
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }

        throw lastError ?? AuthError.sessionMissing
    }

    // MARK: - Account deletion (authenticated path)

    /// Permanently deletes the authenticated user's account and all associated
    /// data by calling the `delete-account` Supabase Edge Function.
    ///
    /// The Edge Function uses the service-role key to call
    /// `auth.admin.deleteUser`, which removes the user from `auth.users` and
    /// cascades the deletion to every user-owned table via ON DELETE CASCADE
    /// (food_logs, bodyweight_logs, user_goals/goals, profiles, favorite_foods,
    /// daily_notes, grocery_items).
    ///
    /// The edge function must receive the current session JWT in the
    /// Authorization header. `supabase-swift` initialises the Functions client
    /// with the anon key as its default bearer token, so this call passes the
    /// session JWT explicitly per request.
    ///
    /// After a successful deletion `auth.signOut()` is called locally. The
    /// `authStateChanges` stream fires `.signedOut`, `userState` becomes
    /// `.signedOut`, and `RootView` routes to `AuthView` automatically.
    ///
    /// **Sign in with Apple:** Apple-backed accounts must pass a fresh Apple
    /// authorization code. The Edge Function exchanges/revokes that grant before
    /// deleting the Supabase user. The code is never logged or persisted.
    func deleteAccount(appleAuthorizationCode: String? = nil) async throws {
        guard session != nil else {
            throw DeleteAccountError.notAuthenticated
        }

        let validSession = try await resolveDeleteAccountSession()
        let trimmedAppleCode = appleAuthorizationCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldRevokeApple = validSession.user.hasAppleIdentity
        if shouldRevokeApple, trimmedAppleCode?.isEmpty != false {
            throw DeleteAccountError.appleAuthorizationRequired
        }
        let requestBody = DeleteAccountRequest(appleAuthorizationCode: trimmedAppleCode)

        do {
            debugDeleteAccount("invoking delete-account, appleRevocationRequired=\(shouldRevokeApple)")
            try await SupabaseClientProvider.shared.functions
                .invoke(
                    "delete-account",
                    options: FunctionInvokeOptions(
                        headers: [
                            "Authorization": "Bearer \(validSession.accessToken)"
                        ],
                        body: requestBody
                    )
                )
        } catch {
            debugDeleteAccount("edge function invocation failed: \(describeDeleteAccountError(error))")
            SentryMonitoring.captureNonFatal(
                error,
                operation: "delete_account",
                tags: ["stage": "edge_function_invoke"]
            )
            throw DeleteAccountError.serverError
        }

        debugDeleteAccount("edge function deletion succeeded")

        // Sign out locally. The JWT is now invalid (user deleted on server),
        // so signOut may return an error. The authStateChanges stream normally
        // fires .signedOut and RootView re-routes automatically.
        do {
            try await SupabaseClientProvider.shared.auth.signOut()
        } catch {
            debugDeleteAccount(
                "local signOut failed after deletion: \(Self.sanitizedAuthDebugDescription(error))"
            )
            // Local signOut failed (invalid JWT, network issue) and the auth
            // observer may not fire. Force-clear session state so the user
            // isn't stuck in an authenticated state with a deleted account.
            clearAuthenticatedState()
        }
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

    /// Google OAuth callback URL. Defined as a static constant so the
    /// force-unwrap is validated once at app startup, not at call time.
    private static let googleRedirectURL = URL(string: "akfit://auth-callback")!

    func signInWithGoogle() async throws {
        pendingAppleDisplayName = nil
        try await SupabaseClientProvider.shared.auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.googleRedirectURL
        )
    }

    // MARK: - Apple credential capture

    /// Extracts a usable display name from the Apple credential fields.
    /// Called from `AuthView` before the Supabase sign-in so the name is
    /// available when `OnboardingView` mounts.
    func setPendingAppleCredentials(fullName: PersonNameComponents?, email: String?) {
        // Build "First Last" from Apple-provided name components.
        let parts = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let joined = parts.joined(separator: " ")

        if !joined.isEmpty {
            pendingAppleDisplayName = joined
        } else if let email, let prefix = email.split(separator: "@").first, !prefix.isEmpty {
            pendingAppleDisplayName = String(prefix)
        } else {
            pendingAppleDisplayName = nil
        }
    }

    // MARK: - Post-onboarding updates

    /// Called by `OnboardingView` (results step) after the goal and profile
    /// have been persisted. Routes to `MainTabView` without an extra network
    /// round-trip. Handles both guest and authenticated paths.
    func markOnboarded(goal: UserGoal, profile: UserProfile) {
        pendingAppleDisplayName = nil
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

    private func describeDeleteAccountError(_ error: Error) -> String {
        if let functionError = error as? FunctionsError {
            switch functionError {
            case .relayError:
                return "relay error"
            case let .httpError(code, _):
                return "http \(code)"
            }
        }

        return "unexpected error"
    }

    private func resolveDeleteAccountSession() async throws -> Session {
        let auth = SupabaseClientProvider.shared.auth
        let functionURL = AppConfig.supabaseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("delete-account")

        debugDeleteAccount("app Supabase URL \(AppConfig.supabaseURL.absoluteString)")
        debugDeleteAccount("delete-account function URL \(functionURL.absoluteString)")

        var validSession: Session
        do {
            validSession = try await auth.session
            session = validSession
            debugDeleteAccount(
                "using session for current user, expired=\(validSession.isExpired), tokenPresent=\(!validSession.accessToken.isEmpty)"
            )
        } catch {
            debugDeleteAccount("failed to resolve valid session before deletion: \(describeDeleteAccountAuthError(error))")
            throw DeleteAccountError.notAuthenticated
        }

        do {
            _ = try await auth.user(jwt: validSession.accessToken)
            debugDeleteAccount("validated session JWT against current Supabase project")
        } catch {
            debugDeleteAccount("session JWT validation failed: \(describeDeleteAccountAuthError(error))")

            guard isInvalidJWTError(error) else {
                throw DeleteAccountError.serverError
            }

            do {
                debugDeleteAccount("attempting session refresh after invalid JWT")
                validSession = try await auth.refreshSession(refreshToken: validSession.refreshToken)
                session = validSession
                debugDeleteAccount(
                    "refreshed session for current user, expired=\(validSession.isExpired), tokenPresent=\(!validSession.accessToken.isEmpty)"
                )
                _ = try await auth.user(jwt: validSession.accessToken)
                debugDeleteAccount("validated refreshed session JWT against current Supabase project")
            } catch {
                debugDeleteAccount("session refresh/revalidation failed: \(describeDeleteAccountAuthError(error))")
                try? await auth.signOut(scope: .local)
                clearAuthenticatedState()
                throw DeleteAccountError.notAuthenticated
            }
        }

        SupabaseClientProvider.shared.functions.setAuth(token: validSession.accessToken)
        return validSession
    }

    private func describeDeleteAccountAuthError(_ error: Error) -> String {
        Self.sanitizedAuthDebugDescription(error)
    }

    static func sanitizedAuthDebugDescription(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case let .api(_, errorCode, _, underlyingResponse):
                return "auth api \(underlyingResponse.statusCode), code: \(errorCode.rawValue)"
            case .jwtVerificationFailed:
                return "jwt verification failed"
            default:
                return "auth error"
            }
        }

        return "unexpected error"
    }

    private func isInvalidJWTError(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            switch authError {
            case .jwtVerificationFailed:
                return true
            case let .api(_, errorCode, _, _):
                return errorCode == .invalidJWT || errorCode == .badJWT
            default:
                return false
            }
        }

        let description = String(describing: error).lowercased()
        return description.contains("invalid jwt") || description.contains("bad jwt")
    }

    private static func isInvalidOrExpiredRecoveryError(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            switch authError {
            case .sessionMissing, .jwtVerificationFailed:
                return true
            case let .api(_, errorCode, _, _):
                return [
                    .badCodeVerifier,
                    .badJWT,
                    .flowStateExpired,
                    .flowStateNotFound,
                    .invalidJWT,
                    .otpExpired,
                    .sessionExpired,
                    .sessionNotFound,
                ].contains(errorCode)
            case .implicitGrantRedirect, .pkceGrantCodeExchange:
                return true
            default:
                return false
            }
        }

        return false
    }

    private static let passwordRecoveryPendingKey = "akfit.auth.passwordRecoveryPending"
    private static let passwordRecoveryExpectedStateKey = "akfit.auth.passwordRecoveryExpectedState"

    private static var isPasswordRecoveryPending: Bool {
        UserDefaults.standard.bool(forKey: passwordRecoveryPendingKey)
    }

    private static func setPasswordRecoveryPending(_ isPending: Bool) {
        if isPending {
            UserDefaults.standard.set(true, forKey: passwordRecoveryPendingKey)
        } else {
            UserDefaults.standard.removeObject(forKey: passwordRecoveryPendingKey)
        }
    }

    private static var expectedPasswordRecoveryState: String? {
        guard let state = UserDefaults.standard.string(forKey: passwordRecoveryExpectedStateKey),
              !state.isEmpty
        else {
            return nil
        }
        return state
    }

    private static func setExpectedPasswordRecoveryState(_ state: String?) {
        if let state, !state.isEmpty {
            UserDefaults.standard.set(state, forKey: passwordRecoveryExpectedStateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: passwordRecoveryExpectedStateKey)
        }
    }

    private static func clearPasswordRecoveryPersistence() {
        setPasswordRecoveryPending(false)
        setExpectedPasswordRecoveryState(nil)
    }

    private static func isExpectedPasswordRecoveryURL(_ url: URL) -> Bool {
        guard let expected = expectedPasswordRecoveryState else { return false }
        return PasswordRecoveryLink.state(in: url) == expected
    }

    private func debugDeleteAccount(_ message: String) {
        #if DEBUG
        print("[DeleteAccount] \(message)")
        #endif
    }

    private func debugAuthWrite(_ message: String) {
        #if DEBUG
        print("[AuthWrite] \(message)")
        #endif
    }
}

private struct DeleteAccountRequest: Encodable {
    let appleAuthorizationCode: String?
}

// MARK: - Account deletion error

/// Describes why `AuthManager.deleteAccount()` failed.
/// Conforms to `LocalizedError` so `error.localizedDescription` is
/// user-facing and can be displayed directly in `SettingsView`.
enum DeleteAccountError: LocalizedError {
    /// No active Supabase session — the user must sign in again.
    case notAuthenticated
    /// Sign in with Apple requires a fresh grant before account deletion.
    case appleAuthorizationRequired
    /// The Edge Function returned an error or the network request failed.
    case serverError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No active session. Please sign in again before deleting your account."
        case .appleAuthorizationRequired:
            return "Please confirm with Sign in with Apple before deleting this account."
        case .serverError:
            return "Account deletion failed. Please check your connection and try again."
        }
    }
}

extension User {
    var hasAppleIdentity: Bool {
        if identities?.contains(where: { $0.provider.caseInsensitiveCompare("apple") == .orderedSame }) == true {
            return true
        }

        if let provider = appMetadata["provider"]?.stringValue,
           provider.caseInsensitiveCompare("apple") == .orderedSame {
            return true
        }

        let providers = appMetadata["providers"]?.arrayValue?
            .compactMap(\.stringValue) ?? []
        return providers.contains { $0.caseInsensitiveCompare("apple") == .orderedSame }
    }
}

// MARK: - Password recovery routing

enum PasswordRecoveryState: Equatable {
    case inactive
    case processingLink
    case ready
    case invalidLink
    case passwordUpdated
}

enum PasswordRecoveryLink {
    static func makeState() -> String {
        UUID().uuidString.lowercased()
    }

    static func redirectURL(state: String) -> URL {
        var components = URLComponents()
        components.scheme = "akfit"
        components.host = "auth-callback"
        components.queryItems = [
            URLQueryItem(name: "flow", value: "password-recovery"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    static func isRecoveryURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "akfit" else { return false }
        guard url.host?.lowercased() == "auth-callback" else { return false }

        let params = parameters(in: url)
        if params["flow"] == "password-recovery" { return true }
        if params["type"] == "recovery" { return true }

        return false
    }

    static func state(in url: URL) -> String? {
        parameters(in: url)["state"]
    }

    private static func parameters(in url: URL) -> [String: String] {
        var values: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                values[item.name] = item.value
            }
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: "?\(fragment)") {
            for item in fragmentComponents.queryItems ?? [] {
                values[item.name] = item.value
            }
        }

        return values
    }
}

enum PasswordRecoveryError: LocalizedError, Equatable {
    case invalidOrExpiredLink
    case updateFailed

    var errorDescription: String? {
        switch self {
        case .invalidOrExpiredLink:
            return "This recovery link is invalid or expired. Request a new link and open it on this device."
        case .updateFailed:
            return "Couldn't update your password. Check your connection and try again."
        }
    }
}
