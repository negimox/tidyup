import SwiftUI

struct MainTabView: View {
    @Environment(DashboardViewModel.self) private var dashboardViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                DashboardView()
            }
            if dashboardViewModel.scanResult != nil {
                Tab("Compress", systemImage: "arrow.down.right.and.arrow.up.left") {
                    CompressVideosView()
                }
            }
            Tab("Vault", systemImage: "lock.shield") {
                VaultView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
