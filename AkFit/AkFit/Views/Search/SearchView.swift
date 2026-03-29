import SwiftUI

/// Placeholder food search screen.
///
/// Next milestone: implement food search using the Supabase foods table
/// (or an external nutrition API), with result rows showing calories and
/// macros, fast tap-to-log, and barcode scan entry point.
struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Search")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
