import SwiftUI

/// Practical settings screen.
///
/// Shows the signed-in account email, the user's current calorie and macro
/// targets, and an "Edit targets" action that presents `EditGoalView` as a sheet.
/// Sign-out is at the bottom.
///
/// **Data sources:**
/// - `authManager.currentUserEmail` — account identifier
/// - `authManager.goal` — targets and goal context (never nil inside `MainTabView`,
///   which is only shown to onboarded users)
struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var showEditGoal   = false
    @State private var isSigningOut   = false
    @State private var signOutError: String? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                accountSection
                if authManager.goal != nil {
                    targetsSection
                }
                signOutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditGoal) {
                if let goal = authManager.goal {
                    EditGoalView(goal: goal)
                        .environment(authManager)
                }
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Email", value: authManager.currentUserEmail ?? "—")
        }
    }

    private var targetsSection: some View {
        Section("Daily targets") {
            if let goal = authManager.goal {
                LabeledContent("Calories",
                               value: "\(goal.targetCalories) kcal")
                LabeledContent("Protein",
                               value: "\(goal.targetProteinG)g")
                LabeledContent("Carbs",
                               value: "\(goal.targetCarbsG)g")
                LabeledContent("Fat",
                               value: "\(goal.targetFatG)g")

                LabeledContent("Goal", value: goalContext(goal))
                    .foregroundStyle(.secondary)

                Button("Edit targets") {
                    showEditGoal = true
                }
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                signOut()
            } label: {
                HStack {
                    Text("Sign out")
                    Spacer()
                    if isSigningOut { ProgressView() }
                }
            }
            .disabled(isSigningOut)

            if let signOutError {
                Text(signOutError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    /// Returns a concise goal context string, e.g. "Fat Loss · Moderate"
    /// or just "Maintenance" when pace is not applicable.
    private func goalContext(_ goal: UserGoal) -> String {
        if goal.goalType == .maintenance { return goal.goalType.displayName }
        if let pace = goal.pace {
            return "\(goal.goalType.displayName) · \(pace.displayName)"
        }
        return goal.goalType.displayName
    }

    private func signOut() {
        isSigningOut = true
        signOutError = nil
        Task {
            defer { isSigningOut = false }
            do {
                try await authManager.signOut()
                // RootView re-routes to AuthView via AuthManager state change.
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
}

#Preview("Signed in, no goal") {
    SettingsView()
        .environment(AuthManager(previewMode: true))
}
