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
    @Environment(AuthManager.self)         private var authManager
    @Environment(HealthKitService.self)    private var healthKit
    @Environment(NotificationService.self) private var notifications

    @State private var showEditGoal          = false
    @State private var showEditProfile       = false
    @State private var isSigningOut          = false
    @State private var signOutError: String? = nil
    @State private var showSignOutConfirm    = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                accountSection
                if authManager.goal != nil {
                    profileSection
                    targetsSection
                }
                remindersSection
                if healthKit.isAvailable {
                    healthSection
                }
                signOutSection
            }
            .onAppear {
                healthKit.checkAuthorization()
                Task { await notifications.checkAuthorization() }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditGoal) {
                if let goal = authManager.goal {
                    EditGoalView(goal: goal, profile: authManager.profile)
                        .environment(authManager)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let goal = authManager.goal {
                    EditProfileView(goal: goal, profile: authManager.profile)
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

    // MARK: - Profile section

    private var profileSection: some View {
        Section {
            if let profile = authManager.profile {
                if let age = profile.age {
                    LabeledContent("Age", value: "\(age)")
                }
                if let cm = profile.heightCm {
                    LabeledContent("Height", value: formattedHeight(cm))
                }
                if let kg = profile.weightKg {
                    LabeledContent("Weight", value: formattedWeight(kg))
                }
                Button {
                    showEditProfile = true
                } label: {
                    HStack {
                        Text("Edit Profile")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Profile")
        }
    }

    // MARK: - Targets section

    private var targetsSection: some View {
        Section {
            if let goal = authManager.goal {
                // Calories — primary metric, no color accent.
                LabeledContent {
                    Text("\(goal.dailyCalories) kcal")
                        .monospacedDigit()
                } label: {
                    Text("Calories")
                }

                // Macros — color-coded to match the dashboard and food log rows.
                LabeledContent {
                    Text("\(goal.dailyProtein)g")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                } label: {
                    Text("Protein")
                }

                LabeledContent {
                    Text("\(goal.dailyCarbs)g")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                } label: {
                    Text("Carbs")
                }

                LabeledContent {
                    Text("\(goal.dailyFat)g")
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

    // MARK: - Reminders section

    private var remindersSection: some View {
        Section {
            // Enable/disable toggle
            Toggle(isOn: Binding(
                get: { notifications.isEnabled },
                set: { notifications.setEnabled($0) }
            )) {
                Text("Daily Reminder")
            }

            // Time picker and permission state — only relevant when enabled.
            if notifications.isEnabled {
                switch notifications.authStatus {

                case .authorized:
                    // Time picker — compact style shows as a tappable time button.
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { notifications.reminderTime },
                            set: { notifications.updateReminderTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                case .denied:
                    // Notification permission was denied — guide user to fix it.
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications are disabled")
                                .foregroundStyle(.primary)
                            Text("Enable in Settings → AkFit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                case .notDetermined:
                    // Brief transitional state while the permission prompt is showing.
                    EmptyView()
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            if notifications.isEnabled && notifications.authStatus == .authorized {
                Text("Reminded once per day. Logging food cancels that day's reminder.")
                    .foregroundStyle(.secondary)
            } else if notifications.isEnabled && notifications.authStatus == .denied {
                Text("Allow notifications in Settings to activate daily reminders.")
                    .foregroundStyle(.secondary)
            }
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
        let paceName: String? = goal.targetPace.map {
            switch $0 {
            case .slow:     "Slow"
            case .moderate: "Moderate"
            case .fast:     "Fast"
            }
        }
        if let paceName { return "\(goal.goalType.displayName) · \(paceName)" }
        return goal.goalType.displayName
    }

    /// Formats a centimetre value as feet and inches, e.g. "5′ 7″".
    private func formattedHeight(_ cm: Double) -> String {
        let (ft, ins) = OnboardingData.cmToFeetInches(cm)
        return "\(ft)′ \(ins)″"
    }

    /// Formats a kilogram value as whole pounds, e.g. "182 lbs".
    private func formattedWeight(_ kg: Double) -> String {
        "\(OnboardingData.kgToLbs(kg)) lbs"
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
            targetWeight: nil, targetPace: .moderate,
            dailyCalories: 2100, dailyProtein: 165,
            dailyCarbs: 220, dailyFat: 65,
            createdAt: Date(), updatedAt: Date()
        ),
        profile: UserProfile(
            id: UUID(), displayName: nil,
            heightCm: 178, weightKg: 82, birthdate: "1992-01-01",
            createdAt: Date(), updatedAt: Date()
        )
    )
    return SettingsView()
        .environment(auth)
        .environment(HealthKitService())
        .environment(NotificationService())
}

#Preview("Signed in, no goal") {
    SettingsView()
        .environment(AuthManager(previewMode: true))
        .environment(HealthKitService())
        .environment(NotificationService())
}
