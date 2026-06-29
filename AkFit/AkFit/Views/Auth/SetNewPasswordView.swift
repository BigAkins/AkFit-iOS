import SwiftUI

enum PasswordRecoveryValidation: Equatable {
    static let minimumLength = 6

    case valid
    case emptyPassword
    case passwordTooShort
    case passwordMismatch

    static func validate(password: String, confirmation: String) -> PasswordRecoveryValidation {
        if password.isEmpty && confirmation.isEmpty { return .emptyPassword }
        if password.count < minimumLength { return .passwordTooShort }
        if password != confirmation { return .passwordMismatch }
        return .valid
    }

    var message: String? {
        switch self {
        case .valid:
            return nil
        case .emptyPassword:
            return "Enter a new password."
        case .passwordTooShort:
            return "Minimum \(Self.minimumLength) characters."
        case .passwordMismatch:
            return "Passwords do not match."
        }
    }
}

struct SetNewPasswordView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var password: String = ""
    @State private var confirmation: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private var validation: PasswordRecoveryValidation {
        PasswordRecoveryValidation.validate(
            password: password,
            confirmation: confirmation
        )
    }

    private var canSubmit: Bool {
        validation == .valid && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            content
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    @ViewBuilder
    private var content: some View {
        switch authManager.passwordRecoveryState {
        case .inactive:
            EmptyView()
        case .processingLink:
            recoveryLoadingView
        case .ready:
            formView
        case .invalidLink:
            invalidLinkView
        case .passwordUpdated:
            successView
        }
    }

    private var recoveryLoadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 8) {
                Text("Opening recovery link")
                    .font(.system(size: 24, weight: .bold))

                Text("Hang tight while AkFit checks your link.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var formView: some View {
        VStack(spacing: 24) {
            Image("akfit_logo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 84)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                Text("Set New Password")
                    .font(.system(size: 28, weight: .bold))

                Text("Choose a new password for your AkFit account.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                SecureField("New password", text: $password)
                    .textContentType(.newPassword)
                    .passwordFieldStyle()

                SecureField("Confirm password", text: $confirmation)
                    .textContentType(.newPassword)
                    .passwordFieldStyle()

                if let message = inlineValidationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(validation == .passwordMismatch ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .disabled(isSubmitting)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(Color(UIColor.systemBackground))
                    } else {
                        Text("Update Password")
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .background(canSubmit ? Color.primary : Color.secondary.opacity(0.35))
            .foregroundStyle(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(!canSubmit)

            Button("Back to Sign In") {
                Task { await authManager.cancelPasswordRecovery() }
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .disabled(isSubmitting)
        }
        .animation(.easeInOut(duration: 0.15), value: validation)
        .animation(.easeInOut(duration: 0.15), value: errorMessage)
    }

    private var invalidLinkView: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Recovery Link Expired")
                    .font(.system(size: 24, weight: .bold))

                Text("Request a new password reset link, then open it on this device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(invalidLinkButtonTitle) {
                authManager.dismissPasswordRecovery()
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.primary)
            .foregroundStyle(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Password Updated")
                    .font(.system(size: 24, weight: .bold))

                Text("Your new password is ready to use.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Continue") {
                authManager.dismissPasswordRecovery()
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.primary)
            .foregroundStyle(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var inlineValidationMessage: String? {
        guard !password.isEmpty || !confirmation.isEmpty else { return nil }
        return validation.message
    }

    private var invalidLinkButtonTitle: String {
        authManager.userState == .signedOut ? "Back to Sign In" : "Done"
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true
        let submittedPassword = password

        Task {
            defer { isSubmitting = false }
            do {
                try await authManager.updatePasswordAfterRecovery(submittedPassword)
                password = ""
                confirmation = ""
            } catch let error as PasswordRecoveryError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = PasswordRecoveryError.updateFailed.localizedDescription
            }
        }
    }
}

private extension View {
    func passwordFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SetNewPasswordView()
        .environment(AuthManager(previewMode: true))
}
