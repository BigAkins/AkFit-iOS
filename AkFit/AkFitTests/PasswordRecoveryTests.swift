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
            PasswordRecoveryValidation.validate(password: "12345", confirmation: "12345")
                == .passwordTooShort
        )
    }

    @Test func mismatchedPasswords_areRejected() {
        #expect(
            PasswordRecoveryValidation.validate(
                password: "123456",
                confirmation: "654321"
            ) == .passwordMismatch
        )
    }

    @Test func matchingValidPasswords_pass() {
        #expect(
            PasswordRecoveryValidation.validate(
                password: "123456",
                confirmation: "123456"
            ) == .valid
        )
    }
}

@MainActor
struct PasswordRecoveryLinkTests {

    @Test func redirectURL_reusesAkFitAuthCallbackScheme() {
        #expect(PasswordRecoveryLink.redirectURL.scheme == "akfit")
        #expect(PasswordRecoveryLink.redirectURL.host == "auth-callback")
        #expect(PasswordRecoveryLink.isRecoveryURL(PasswordRecoveryLink.redirectURL))
    }

    @Test func recoveryURLWithError_isStillHandledForGracefulFailure() throws {
        let url = try #require(
            URL(string: "akfit://auth-callback?flow=password-recovery&error_code=flow_state_expired")
        )

        #expect(PasswordRecoveryLink.isRecoveryURL(url))
    }

    @Test func implicitRecoveryFragment_isRecognized() throws {
        let url = try #require(
            URL(string: "akfit://auth-callback#access_token=token&type=recovery")
        )

        #expect(PasswordRecoveryLink.isRecoveryURL(url))
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

@MainActor
struct AuthManagerPasswordRecoveryTests {

    @Test func passwordRecoveryEvent_presentsRecoveryScreen() async {
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
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())
        await manager.handle(event: .signedOut, session: nil)

        #expect(manager.passwordRecoveryState == .inactive)
        #expect(!manager.isPasswordRecoveryPresented)
    }

    @Test func dismissPasswordRecovery_doesNotDismissReadyRecoverySession() async {
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .passwordRecovery, session: Self.makeSession())
        manager.dismissPasswordRecovery()

        #expect(manager.passwordRecoveryState == .ready)

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func malformedRecoveryURL_marksLinkInvalid() async throws {
        let manager = AuthManager(previewMode: true)
        let url = try #require(URL(string: "akfit://auth-callback?flow=password-recovery"))

        let handled = await manager.handleIncomingURL(url)

        #expect(handled)
        #expect(manager.passwordRecoveryState == .invalidLink)
        #expect(!manager.isLoading)
    }

    @Test func malformedRecoveryURL_doesNotClearExistingSession() async throws {
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
}
