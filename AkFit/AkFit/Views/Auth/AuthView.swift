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

            // Wordmark
            Text("AkFit")
                .font(.system(size: 40, weight: .bold, design: .rounded))
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

            // Primary CTA
            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
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
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .disabled(isSubmitting || !isFormValid)
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
    /// Maps a raw Supabase / network error to a short, user-friendly message.
    ///
    /// Supabase SDK error messages are often technical or include internal codes.
    /// This mapping ensures beta testers see plain English rather than SDK jargon.
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
