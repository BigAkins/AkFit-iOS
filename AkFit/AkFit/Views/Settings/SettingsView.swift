import SwiftUI

/// Settings screen.
///
/// Surfaces account identity, current daily targets, an entry point into
/// `EditGoalView`, sign-out, and account deletion (App Store requirement).
///
/// **Data sources:**
/// - `authManager.currentUserEmail` — account identifier
/// - `authManager.profile.createdAt` — member-since year
/// - `authManager.goal` — targets and goal context (never nil inside `MainTabView`)
struct SettingsView: View {
    @Environment(AuthManager.self)         private var authManager
    @Environment(FoodLogStore.self)        private var logStore
    @Environment(FavoriteFoodStore.self)   private var favStore
    @Environment(BodyweightStore.self)     private var weightStore
    @Environment(DailyNoteStore.self)      private var noteStore
    @Environment(GroceryListStore.self)    private var groceryStore
    @Environment(HealthKitService.self)    private var healthKit
    @Environment(NotificationService.self) private var notifications

    @State private var showEditGoal               = false
    @State private var showEditProfile            = false
    @State private var isSigningOut               = false
    @State private var signOutError: String?      = nil
    @State private var showSignOutConfirm         = false
    @State private var showExitGuestConfirm       = false
    @State private var showDeleteAccountConfirm   = false
    @State private var isDeletingAccount          = false
    @State private var deleteAccountError: String? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                accountSection
                if authManager.isGuest {
                    guestBannerSection
                }
                if authManager.goal != nil {
                    profileSection
                    targetsSection
                }
                remindersSection
                healthSection
                exitOrSignOutSection
            }
            .onAppear {
                healthKit.checkAuthorization()
                Task { await notifications.checkAuthorization() }
                if let userId = authManager.currentUserId {
                    Task { await weightStore.refreshWeek(userId: userId) }
                }
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
            // Sign-out confirmation dialog (authenticated users).
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
            // Exit Guest Mode confirmation dialog — warns about permanent local data deletion.
            .confirmationDialog(
                "Exit Guest Mode",
                isPresented: $showExitGuestConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Data & Exit", role: .destructive) { exitGuestMode() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All your local data — food logs, weight entries, and goals — will be permanently deleted. This cannot be undone.")
            }
            // Delete Account confirmation dialog — shown before the irreversible server-side deletion.
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete My Account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all associated data — food logs, weight history, targets, and notes. This cannot be undone.")
            }
        }
    }

    // MARK: - Account section

    private var accountSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                    if authManager.isGuest {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    } else {
                        // Avatar initial — display name preferred over email initial.
                        Text(avatarInitial)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    if authManager.isGuest {
                        Text("Guest")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Local data only — no account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        // When a display name exists, show it prominently and
                        // demote the email to a secondary line beneath it.
                        if let name = authManager.profile?.displayName,
                           !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let email = authManager.currentUserEmail {
                                Text(email)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        } else {
                            Text(authManager.currentUserEmail ?? "Signed in")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        if let created = authManager.profile?.createdAt {
                            Text("Member since \(memberYear(created))")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Guest banner section

    private var guestBannerSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "lock.icloud")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your data stays on this device")
                        .font(.footnote.weight(.medium))
                    Text("Create an account to back up your data and sync it across devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
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
                // Prefer the latest bodyweight log over the profile snapshot.
                // Falls back to profile.weightKg if no log exists.
                if let kg = weightStore.weekLogs.last?.weightKg ?? profile.weightKg {
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
            Text("Body stats")
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
                } else if !healthKit.isAvailable {
                    Button("Unavailable") { }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(true)
                } else if healthKit.authStatus == .notDetermined {
                    Button {
                        Task { await healthKit.requestAuthorization() }
                    } label: {
                        if healthKit.isRequesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color(UIColor.systemBackground))
                        } else {
                            Text("Connect")
                                .foregroundStyle(Color(UIColor.systemBackground))
                        }
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .disabled(healthKit.isRequesting)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("Health")
        }
    }

    private var healthStatusCaption: String {
        if !healthKit.isAvailable {
            return "Apple Health isn't available on this device"
        }
        switch healthKit.authStatus {
        case .authorized:    return "Exporting food logs and weight to Health"
        case .denied:        return "Enable in Settings → Privacy & Security → Health"
        case .notDetermined: return "Export food logs and weight to Apple Health"
        }
    }

    // MARK: - Exit / sign-out section

    @ViewBuilder
    private var exitOrSignOutSection: some View {
        if authManager.isGuest {
            // Guest users exit guest mode (destructive — deletes all local data).
            Section {
                Button {
                    showExitGuestConfirm = true
                } label: {
                    Text("Exit Guest Mode")
                        .foregroundStyle(.red)
                }
            }
        } else {
            // Authenticated users: sign out.
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
                .disabled(isSigningOut || isDeletingAccount)

                if let err = signOutError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            // Authenticated users: account deletion (App Store Guideline 5.1.1).
            Section {
                Button {
                    showDeleteAccountConfirm = true
                } label: {
                    HStack {
                        Text("Delete Account")
                            .foregroundStyle(.red)
                        Spacer()
                        if isDeletingAccount { ProgressView() }
                    }
                }
                .disabled(isDeletingAccount || isSigningOut)

                if let err = deleteAccountError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Permanently deletes your account and all associated data.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    /// First letter of the display name (preferred) or email address, uppercased.
    /// Used as the identity marker in the avatar circle.
    private var avatarInitial: String {
        if let name = authManager.profile?.displayName,
           let first = name.trimmingCharacters(in: .whitespaces).first {
            return String(first).uppercased()
        }
        return authManager.currentUserEmail?.first.map(String.init)?.uppercased() ?? "?"
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

    private func deleteAccount() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            defer { isDeletingAccount = false }
            do {
                try await authManager.deleteAccount()
                clearUserOwnedState()
                // AuthManager signs out locally → authStateChanges fires .signedOut
                // → RootView re-routes to AuthView automatically.
            } catch {
                deleteAccountError = error.localizedDescription
            }
        }
    }

    /// Exits guest mode and destroys all local data.
    ///
    /// Called after the user confirms the destructive confirmation dialog.
    /// Resets in-memory store state before clearing guest data so stale
    /// entries don't linger in memory after routing back to `AuthView`.
    private func exitGuestMode() {
        logStore.reset()
        weightStore.reset()
        noteStore.reset()
        groceryStore.reset()
        authManager.exitGuestMode()
        // AuthManager sets userState = .signedOut → RootView re-routes to AuthView.
    }

    private func clearUserOwnedState() {
        logStore.reset()
        favStore.reset()
        weightStore.reset()
        noteStore.reset()
        groceryStore.reset()
    }
}

// MARK: - Preview

#Preview("With goal and name") {
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
            id: UUID(), displayName: "Alex",
            heightCm: 178, weightKg: 82, birthdate: "1992-01-01",
            createdAt: Date(), updatedAt: Date()
        )
    )
    return SettingsView()
        .environment(auth)
        .environment(FoodLogStore())
        .environment(BodyweightStore())
        .environment(DailyNoteStore())
        .environment(GroceryListStore())
        .environment(HealthKitService())
        .environment(NotificationService())
}

#Preview("With goal, no name") {
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
        .environment(FoodLogStore())
        .environment(BodyweightStore())
        .environment(DailyNoteStore())
        .environment(GroceryListStore())
        .environment(HealthKitService())
        .environment(NotificationService())
}

#Preview("Signed in, no goal") {
    SettingsView()
        .environment(AuthManager(previewMode: true))
        .environment(FoodLogStore())
        .environment(BodyweightStore())
        .environment(DailyNoteStore())
        .environment(GroceryListStore())
        .environment(HealthKitService())
        .environment(NotificationService())
}
