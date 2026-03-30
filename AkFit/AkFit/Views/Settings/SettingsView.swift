import SwiftUI

/// Settings screen.
///
/// Surfaces account identity, current daily targets, an entry point into
/// `EditGoalView`, and sign-out. Intentionally scoped — does not include
/// notification preferences, billing, or account deletion in MVP.
///
/// **Data sources:**
/// - `authManager.currentUserEmail` — account identifier
/// - `authManager.profile.createdAt` — member-since year
/// - `authManager.goal` — targets and goal context (never nil inside `MainTabView`)
struct SettingsView: View {
    @Environment(AuthManager.self)      private var authManager
    @Environment(HealthKitService.self) private var healthKit

    @State private var showEditGoal          = false
    @State private var isSigningOut          = false
    @State private var signOutError: String? = nil
    @State private var showSignOutConfirm    = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                accountSection
                if authManager.goal != nil {
                    targetsSection
                }
                if healthKit.isAvailable {
                    healthSection
                }
                signOutSection
            }
            .onAppear {
                healthKit.checkAuthorization()
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditGoal) {
                if let goal = authManager.goal {
                    EditGoalView(goal: goal)
                        .environment(authManager)
                }
            }
            // Confirmation dialog — shown before sign-out fires.
            // Keeps the destructive action intentional and safe against accidental taps.
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
        }
    }

    // MARK: - Account section

    private var accountSection: some View {
        Section {
            HStack(spacing: 14) {
                // Avatar circle — uses email initial as identity marker.
                // No profile photo in MVP; no network call required.
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                    Text(emailInitial)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(authManager.currentUserEmail ?? "Signed in")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let created = authManager.profile?.createdAt {
                        Text("Member since \(memberYear(created))")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Targets section

    private var targetsSection: some View {
        Section {
            if let goal = authManager.goal {
                // Calories — primary metric, no color accent.
                LabeledContent {
                    Text("\(goal.targetCalories) kcal")
                        .monospacedDigit()
                } label: {
                    Text("Calories")
                }

                // Macros — color-coded to match the dashboard and food log rows.
                LabeledContent {
                    Text("\(goal.targetProteinG)g")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                } label: {
                    Text("Protein")
                }

                LabeledContent {
                    Text("\(goal.targetCarbsG)g")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                } label: {
                    Text("Carbs")
                }

                LabeledContent {
                    Text("\(goal.targetFatG)g")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                } label: {
                    Text("Fat")
                }

                // Goal type + pace context.
                LabeledContent("Goal", value: goalContext(goal))
                    .foregroundStyle(.secondary)

                // Edit targets — styled as a navigation action row, not a data row.
                // The chevron visually separates it from the values above.
                Button {
                    showEditGoal = true
                } label: {
                    HStack {
                        Text("Edit Targets")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Daily targets")
        }
    }

    // MARK: - Health section

    private var healthSection: some View {
        Section {
            HStack(spacing: 12) {
                // Heart icon — filled and red when connected, outline otherwise.
                Image(systemName: healthKit.authStatus == .authorized ? "heart.fill" : "heart")
                    .foregroundStyle(healthKit.authStatus == .authorized ? .red : Color(.secondaryLabel))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .foregroundStyle(.primary)
                    Text(healthStatusCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Right-side action — shown unless the user has actively denied.
                if healthKit.authStatus == .authorized {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .font(.footnote.weight(.semibold))
                } else if healthKit.authStatus == .notDetermined {
                    Button("Connect") {
                        Task { await healthKit.requestAuthorization() }
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.primary)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("Health")
        }
    }

    private var healthStatusCaption: String {
        switch healthKit.authStatus {
        case .authorized:    return "Exporting food logs and weight to Health"
        case .denied:        return "Enable in Settings → Privacy & Security → Health"
        case .notDetermined: return "Export food logs and weight to Apple Health"
        }
    }

    // MARK: - Sign-out section

    private var signOutSection: some View {
        Section {
            // Button sets the confirmation flag — dialog fires before any sign-out
            // logic runs, preventing accidental account sign-outs.
            Button {
                showSignOutConfirm = true
            } label: {
                HStack {
                    Text("Sign Out")
                        .foregroundStyle(.red)
                    Spacer()
                    if isSigningOut { ProgressView() }
                }
            }
            .disabled(isSigningOut)

            if let err = signOutError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    /// First letter of the email address, uppercased, for the avatar circle.
    private var emailInitial: String {
        authManager.currentUserEmail?.first.map(String.init)?.uppercased() ?? "?"
    }

    /// Formats a date to its 4-digit year string, e.g. "2024".
    private func memberYear(_ date: Date) -> String {
        String(Calendar.current.component(.year, from: date))
    }

    /// Returns a concise goal context string.
    ///
    /// Examples: "Fat Loss · Moderate", "Lean Bulk · Fast", "Maintenance"
    ///
    /// Uses a short pace name to keep the value readable at settings row width.
    /// (The full `Pace.displayName` includes the lb/week detail which is too
    /// verbose for a settings label.)
    private func goalContext(_ goal: UserGoal) -> String {
        if goal.goalType == .maintenance { return goal.goalType.displayName }
        let paceName: String? = goal.pace.map {
            switch $0 {
            case .slow:     "Slow"
            case .moderate: "Moderate"
            case .fast:     "Fast"
            }
        }
        if let paceName { return "\(goal.goalType.displayName) · \(paceName)" }
        return goal.goalType.displayName
    }

    private func signOut() {
        isSigningOut = true
        signOutError = nil
        Task {
            defer { isSigningOut = false }
            do {
                try await authManager.signOut()
                // AuthManager clears session → RootView re-routes to AuthView.
            } catch {
                signOutError = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview("With goal") {
    let auth = AuthManager(previewMode: true)
    auth.markOnboarded(
        goal: UserGoal(
            id: UUID(), userId: UUID(),
            goalType: .fatLoss,
            targetCalories: 2100, targetProteinG: 165,
            targetCarbsG: 220,   targetFatG: 65,
            heightCm: 178, weightKg: 82, age: 32, sex: .male,
            activityLevel: .moderate, pace: .moderate,
            isActive: true, createdAt: Date(), updatedAt: Date()
        ),
        profile: UserProfile(id: UUID(), displayName: nil, createdAt: Date())
    )
    return SettingsView()
        .environment(auth)
        .environment(HealthKitService())
}

#Preview("Signed in, no goal") {
    SettingsView()
        .environment(AuthManager(previewMode: true))
        .environment(HealthKitService())
}
