import Foundation
import Supabase
import Testing
@testable import AkFit

@MainActor
struct PasswordRecoveryValidationTests {

    @Test func emptyPasswords_requireInput() {
        #expect(
            PasswordRecoveryValidation.validate(password: "", confirmation: "")
                == .emptyPassword
        )
    }

    @Test func shortPassword_isRejected() {
        #expect(
            PasswordRecoveryValidation.validate(password: "Password123", confirmation: "Password123")
                == .passwordTooShort
        )
    }

    @Test func passwordWithoutRequiredCharacters_isRejected() {
        #expect(
            PasswordRecoveryValidation.validate(password: "password1234", confirmation: "password1234")
                == .passwordMissingRequiredCharacters
        )
    }

    @Test func mismatchedPasswords_areRejected() {
        #expect(
            PasswordRecoveryValidation.validate(
                password: "Password1234",
                confirmation: "Password5678"
            ) == .passwordMismatch
        )
    }

    @Test func matchingValidPasswords_pass() {
        #expect(
            PasswordRecoveryValidation.validate(
                password: "Password1234",
                confirmation: "Password1234"
            ) == .valid
        )
    }
}

@MainActor
struct PasswordRecoveryLinkTests {

    @Test func redirectURL_reusesAkFitAuthCallbackScheme() {
        let url = PasswordRecoveryLink.redirectURL(state: "state-123")

        #expect(url.scheme == "akfit")
        #expect(url.host == "auth-callback")
        #expect(PasswordRecoveryLink.isRecoveryURL(url))
        #expect(PasswordRecoveryLink.state(in: url) == "state-123")
    }

    @Test func recoveryURLWithError_isStillHandledForGracefulFailure() throws {
        let url = try #require(
            URL(string: "akfit://auth-callback?flow=password-recovery&state=state-123&error_code=flow_state_expired")
        )

        #expect(PasswordRecoveryLink.isRecoveryURL(url))
        #expect(PasswordRecoveryLink.state(in: url) == "state-123")
    }

    @Test func implicitRecoveryFragment_isRecognized() throws {
        let url = try #require(
            URL(string: "akfit://auth-callback#access_token=token&type=recovery&state=state-123")
        )

        #expect(PasswordRecoveryLink.isRecoveryURL(url))
        #expect(PasswordRecoveryLink.state(in: url) == "state-123")
    }

    @Test func plainAuthCallback_isNotTreatedAsRecovery() throws {
        let url = try #require(URL(string: "akfit://auth-callback?code=oauth-code"))

        #expect(!PasswordRecoveryLink.isRecoveryURL(url))
    }

    @Test func recoveryFlowOnWrongHost_isIgnored() throws {
        let url = try #require(URL(string: "akfit://settings?flow=password-recovery"))

        #expect(!PasswordRecoveryLink.isRecoveryURL(url))
    }
}

@Suite(.serialized)
@MainActor
struct AuthManagerPasswordRecoveryTests {

    @Test func passwordRecoveryEvent_presentsRecoveryScreen() async {
        Self.markRecoveryPending()
        defer { Self.clearRecoveryPersistence() }
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())

        #expect(manager.passwordRecoveryState == .ready)
        #expect(manager.isPasswordRecoveryPresented)
        #expect(manager.userState == .authenticated)
        #expect(manager.currentUserId == manager.session?.user.id)
        #expect(manager.session?.accessToken == "access-token")

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func signedOutEvent_clearsRecoveryState() async {
        Self.markRecoveryPending()
        defer { Self.clearRecoveryPersistence() }
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())
        await manager.handle(event: .signedOut, session: nil)

        #expect(manager.passwordRecoveryState == .inactive)
        #expect(!manager.isPasswordRecoveryPresented)
    }

    @Test func dismissPasswordRecovery_doesNotDismissReadyRecoverySession() async {
        Self.markRecoveryPending()
        defer { Self.clearRecoveryPersistence() }
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())
        manager.dismissPasswordRecovery()

        #expect(manager.passwordRecoveryState == .ready)

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func unboundPasswordRecoveryEvent_isRejected() async {
        Self.clearRecoveryPersistence()
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())

        #expect(manager.passwordRecoveryState == .invalidLink)
        #expect(manager.isPasswordRecoveryPresented)
        #expect(manager.session == nil)
    }

    @Test func malformedRecoveryURL_marksLinkInvalid() async throws {
        Self.clearRecoveryPersistence()
        let manager = AuthManager(previewMode: true)
        let url = try #require(URL(string: "akfit://auth-callback?flow=password-recovery"))

        let handled = await manager.handleIncomingURL(url)

        #expect(handled)
        #expect(manager.passwordRecoveryState == .invalidLink)
        #expect(!manager.isLoading)
    }

    @Test func malformedRecoveryURL_doesNotClearExistingSession() async throws {
        Self.markRecoveryPending()
        defer { Self.clearRecoveryPersistence() }
        let manager = AuthManager(previewMode: true)
        let url = try #require(URL(string: "akfit://auth-callback?flow=password-recovery"))

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())
        _ = await manager.handleIncomingURL(url)

        #expect(manager.passwordRecoveryState == .invalidLink)
        #expect(manager.session?.accessToken == "access-token")
    }

    private static func makeSession() -> Session {
        let now = Date()
        let user = User(
            id: UUID(),
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: "user@example.com",
            createdAt: now,
            updatedAt: now
        )

        return Session(
            accessToken: "access-token",
            tokenType: "bearer",
            expiresIn: 3_600,
            expiresAt: now.addingTimeInterval(3_600).timeIntervalSince1970,
            refreshToken: "refresh-token",
            user: user
        )
    }

    private static func markRecoveryPending() {
        UserDefaults.standard.set(true, forKey: "akfit.auth.passwordRecoveryPending")
    }

    private static func clearRecoveryPersistence() {
        UserDefaults.standard.removeObject(forKey: "akfit.auth.passwordRecoveryPending")
        UserDefaults.standard.removeObject(forKey: "akfit.auth.passwordRecoveryExpectedState")
    }
}
