import SwiftUI

/// Settings screen.
///
/// Sign-out is available here for testing auth routing and for normal
/// use. Additional settings (goal editing, notification prefs, account
/// management) will be added in later milestones.
struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isSigningOut: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                if authManager.isAuthenticated {
                    Section("Account") {
                        LabeledContent("Email", value: authManager.currentUserEmail ?? "—")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        signOut()
                    } label: {
                        HStack {
                            Text("Sign out")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func signOut() {
        isSigningOut = true
        errorMessage = nil
        Task {
            defer { isSigningOut = false }
            do {
                try await authManager.signOut()
                // RootView re-routes to AuthView via AuthManager state change.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager(previewMode: true))
}
