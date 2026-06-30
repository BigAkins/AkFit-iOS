import Foundation
import Supabase
import Testing
@testable import AkFit

@MainActor
struct AuthManagerDeleteAccountTests {

    @Test func nonAppleSessionDoesNotRequireAppleReauthorization() async {
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .signedIn, session: Self.makeSession(provider: "email"))

        #expect(!manager.requiresAppleReauthorizationForAccountDeletion)

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func appleIdentityRequiresAppleReauthorization() async {
        let manager = AuthManager(previewMode: true)

        await manager.handle(event: .signedIn, session: Self.makeSession(provider: "apple"))

        #expect(manager.requiresAppleReauthorizationForAccountDeletion)

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func appleProviderMetadataRequiresAppleReauthorization() async {
        let manager = AuthManager(previewMode: true)

        await manager.handle(
            event: .signedIn,
            session: Self.makeSession(provider: "email", appProvider: "apple")
        )

        #expect(manager.requiresAppleReauthorizationForAccountDeletion)

        await manager.handle(event: .signedOut, session: nil)
    }

    @Test func sanitizedAuthDebugDescriptionDoesNotIncludeUnexpectedErrorText() {
        let error = NSError(
            domain: "Auth",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Bearer raw-token refresh-token user@example.com",
            ]
        )

        let description = AuthManager.sanitizedAuthDebugDescription(error)

        #expect(description == "unexpected error")
        #expect(!description.contains("raw-token"))
        #expect(!description.contains("refresh-token"))
        #expect(!description.contains("user@example.com"))
    }

    private static func makeSession(
        provider: String,
        appProvider: String? = nil
    ) -> Session {
        let now = Date()
        let userId = UUID()
        let identity = UserIdentity(
            id: "identity-\(provider)",
            identityId: UUID(),
            userId: userId,
            identityData: [:],
            provider: provider,
            createdAt: now,
            lastSignInAt: now,
            updatedAt: now
        )
        let user = User(
            id: userId,
            appMetadata: [
                "provider": .string(appProvider ?? provider),
                "providers": .array([.string(provider)]),
            ],
            userMetadata: [:],
            aud: "authenticated",
            email: "user@example.com",
            createdAt: now,
            updatedAt: now,
            identities: [identity]
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
