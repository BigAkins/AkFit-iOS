import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }

            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager(previewMode: true))
}
