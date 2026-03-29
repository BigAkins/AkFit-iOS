import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var awaitingConfirmation: Bool = false

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
            }
            .padding(.horizontal, 24)

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

            Button("Back to sign in") {
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
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthManager(previewMode: true))
}
