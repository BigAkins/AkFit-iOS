import AuthenticationServices
import CryptoKit
import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var awaitingConfirmation: Bool = false
    /// Message shown in the password-reset confirmation alert. `nil` hides the alert.
    @State private var resetAlertMessage: String? = nil
    @State private var isResettingPassword: Bool = false
    /// Raw nonce generated before each Apple sign-in presentation.
    /// Stored here so the completion handler can forward it to Supabase.
    @State private var currentNonce: String? = nil

    enum Mode: CaseIterable {
        case signIn, signUp
        var label: String {
            switch self {
            case .signIn: "Sign In"
            case .signUp: "Create Account"
            }
        }
    }

    var body: some View {
        if awaitingConfirmation {
            confirmationView
        } else {
            formView
        }
    }

    // MARK: - Form view

    private var formView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo asset — original rendering preserves brand colours.
            Image("akfit_logo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 84)
                .padding(.bottom, 48)

            // Mode picker
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .onChange(of: mode) {
                errorMessage = nil
            }

            // Fields
            VStack(spacing: 12) {
                inputField(
                    placeholder: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    isSecure: false
                )

                inputField(
                    placeholder: "Password",
                    text: $password,
                    keyboardType: .default,
                    isSecure: true
                )

                // Inline hint — only shown when the user has typed something
                // too short. Avoids a confusing disabled-button state with no explanation.
                if !password.isEmpty && password.count < 6 {
                    Text("Minimum 6 characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.15), value: password.count < 6 && !password.isEmpty)

            // Forgot password — sign-in mode only. Shows an alert after the reset
            // email fires so the user knows to check their inbox.
            if mode == .signIn {
                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        triggerPasswordReset()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .disabled(isResettingPassword)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            Spacer()

            // Bottom auth section — email/password CTA, divider, Sign in with Apple
            VStack(spacing: 16) {
                // Primary CTA
                Button(action: submit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color(UIColor.systemBackground))
                        } else {
                            Text(mode.label)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .background(Color.primary)
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isSubmitting || !isFormValid)

                // "or" divider
                HStack(spacing: 12) {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color(.separator))
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color(.separator))
                }

                // Sign in with Apple — works for both new and returning users.
                // Supabase creates a new account on first use; subsequent sign-ins
                // retrieve the existing session.
                SignInWithAppleButton(mode == .signIn ? .signIn : .signUp) { request in
                    let nonce = Self.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    // Apple receives the *hashed* nonce; the raw nonce goes to Supabase.
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignInResult(result)
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isSubmitting)

                // Sign in with Google via Supabase OAuth / ASWebAuthenticationSession.
                Button(action: signInWithGoogle) {
                    HStack(spacing: 10) {
                        Image("Google PNG")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text(mode == .signIn ? "Sign in with Google" : "Sign up with Google")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(UIColor.systemBackground))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)

                // Guest mode — local-only, no account required.
                Button("Continue as Guest") {
                    authManager.enterGuestMode()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(UIColor.systemBackground))
        // Password-reset confirmation / error alert.
        .alert(
            "Password Reset",
            isPresented: Binding(
                get: { resetAlertMessage != nil },
                set: { if !$0 { resetAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetAlertMessage ?? "")
        }
    }

    // MARK: - Confirmation view (email not yet confirmed)

    private var confirmationView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                Text("Check your email")
                    .font(.system(size: 28, weight: .bold))

                Text("We sent a confirmation link to\n\(email)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Back to Sign In") {
                awaitingConfirmation = false
                mode = .signIn
                password = ""
                errorMessage = nil
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Input field helper

    @ViewBuilder
    private func inputField(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Password reset

    /// Sends a password reset email.
    ///
    /// If the email field is empty, surfaces a prompt instead. After a successful
    /// send, shows a confirmation alert so the user knows to check their inbox.
    private func triggerPasswordReset() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resetAlertMessage = "Enter your email address above and tap 'Forgot password?' again."
            return
        }
        isResettingPassword = true
        Task {
            defer { isResettingPassword = false }
            do {
                try await authManager.sendPasswordReset(email: trimmed)
                resetAlertMessage = "A reset link has been sent to \(trimmed). Check your inbox."
            } catch {
                resetAlertMessage = "Couldn't send reset email. Please try again."
            }
        }
    }

    // MARK: - Validation & submission

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                switch mode {
                case .signIn:
                    try await authManager.signIn(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password
                    )
                    // RootView re-routes automatically via AuthManager state.

                case .signUp:
                    let needsConfirmation = try await authManager.signUp(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password
                    )
                    if needsConfirmation {
                        awaitingConfirmation = true
                    }
                    // If needsConfirmation == false, the authStateChanges stream
                    // fires and RootView re-routes automatically.
                }
            } catch {
                errorMessage = friendlyError(error)
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Handles the `SignInWithAppleButton` completion result.
    ///
    /// On success, calls `authManager.signInWithApple` which triggers the
    /// `authStateChanges` stream — routing to onboarding or the main app is
    /// handled automatically by `RootView`.
    ///
    /// User cancellation (error code 1001) is silently ignored — no error shown.
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            // Set isSubmitting immediately so the UI is locked while the
            // credential extraction and Supabase call complete.
            isSubmitting = true
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData  = credential.identityToken,
                let idToken    = String(data: tokenData, encoding: .utf8),
                let nonce      = currentNonce
            else {
                isSubmitting = false
                errorMessage = "Sign in with Apple failed. Please try again."
                return
            }
            Task {
                defer { isSubmitting = false }
                do {
                    try await authManager.signInWithApple(idToken: idToken, rawNonce: nonce)
                    // authStateChanges fires → RootView re-routes automatically.
                } catch {
                    errorMessage = friendlyError(error)
                }
            }

        case .failure(let error):
            // Code 1001 = user cancelled — don't surface an error for that.
            let nsError = error as NSError
            guard !(nsError.domain == ASAuthorizationError.errorDomain &&
                    nsError.code  == ASAuthorizationError.canceled.rawValue)
            else { return }
            errorMessage = "Sign in with Apple failed. Please try again."
        }
    }

    // MARK: - Sign in with Google

    /// Triggers the Google OAuth flow via Supabase's built-in `ASWebAuthenticationSession`
    /// integration. No browser switch or custom URL scheme registration required.
    ///
    /// On success, `authStateChanges` fires and `RootView` re-routes automatically.
    /// Cancellation (user dismisses the sheet) is silently ignored.
    private func signInWithGoogle() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await authManager.signInWithGoogle()
                // authStateChanges fires → RootView re-routes automatically.
            } catch {
                // ASWebAuthenticationSession cancel — don't surface an error.
                if let webAuthError = error as? ASWebAuthenticationSessionError,
                   webAuthError.code == .canceledLogin {
                    return
                }
                errorMessage = friendlyError(error)
            }
        }
    }

    // MARK: - Nonce helpers

    /// Returns a cryptographically random alphanumeric nonce of `length` characters.
    ///
    /// The *hashed* version (SHA256) is passed to Apple's `ASAuthorizationAppleIDRequest`
    /// so Apple can embed it in the identity token JWT. The *raw* version is forwarded
    /// to Supabase's `signInWithIdToken`, which re-hashes and verifies it — preventing
    /// token replay attacks.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with OSStatus \(status)")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    /// Returns the lowercase hex-encoded SHA256 digest of `input`.
    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func friendlyError(_ error: Error) -> String {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("invalid login credentials") || lower.contains("invalid credentials") {
            return "Incorrect email or password."
        }
        if lower.contains("email not confirmed") {
            return "Please confirm your email before signing in. Check your inbox."
        }
        if lower.contains("already registered") || lower.contains("user already exists") {
            return "An account with this email already exists. Try signing in instead."
        }
        if lower.contains("rate limit") || lower.contains("email rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if lower.contains("network") || lower.contains("connection") ||
           lower.contains("offline") || lower.contains("timed out") {
            return "Connection problem. Check your internet and try again."
        }
        return "Something went wrong. Please try again."
    }
}


#Preview {
    AuthView()
        .environment(AuthManager(previewMode: true))
}
