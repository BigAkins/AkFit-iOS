import SwiftUI

/// Placeholder dashboard screen.
///
/// Next milestone: replace the placeholder content with:
/// - Calorie ring / progress bar (eaten vs. target)
/// - Macro cards (protein, carbs, fat — remaining)
/// - Recent food log entries
/// The floating add button is already wired; its sheet will be
/// the entry point into food search / logging.
struct DashboardView: View {
    @State private var showAddSheet: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                VStack {
                    Spacer()
                    Text("Dashboard")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .navigationTitle("Today")
            }

            // Floating add button — visible only on this tab
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddSheet) {
            // TODO: Replace with food search / logging sheet
            Text("Add food")
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    DashboardView()
}
