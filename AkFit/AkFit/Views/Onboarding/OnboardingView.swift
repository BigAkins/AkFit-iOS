import SwiftUI

/// Placeholder for the onboarding flow.
///
/// This screen is shown when the user is authenticated but has no active goal.
/// The full onboarding implementation (body stats, goal selection, macro
/// calculation) is the next milestone.
///
/// Once onboarding is complete, call `authManager.markOnboarded(goal:profile:)`
/// to route the app to `MainTabView` without a network re-fetch.
struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("Let's set up your\ntargets.")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("We'll use your body stats and goal to\ncalculate your daily calorie and macro targets.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            // TODO: Replace with NavigationStack leading into onboarding steps.
            Button("Get started") {
                // Next milestone: navigate to the first onboarding step
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.primary)
            .foregroundStyle(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    OnboardingView()
        .environment(AuthManager(previewMode: true))
}
