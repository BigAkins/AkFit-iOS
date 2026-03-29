import SwiftUI

/// Placeholder progress / history screen.
///
/// Named `ProgressTabView` (not `ProgressView`) to avoid shadowing SwiftUI's
/// built-in `ProgressView`.
///
/// Next milestone: implement macro history chart, daily log summaries,
/// and streak / adherence stats.
struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Progress")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressTabView()
}
