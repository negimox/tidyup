import SwiftUI
import SwiftData
import Photos
import Contacts
import WidgetKit

@main
struct TidyUpApp: App {

    @State private var didGrantPhotos: Bool = {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }()

    @State private var didGrantContacts: Bool = {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }()

    @State private var dashboardViewModel = DashboardViewModel()
    @State private var selectionStore = SelectionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if didGrantPhotos || didGrantContacts {
                    MainTabView()
                } else {
                    PermissionsPrimerView(
                        didGrantPhotos: $didGrantPhotos,
                        didGrantContacts: $didGrantContacts
                    )
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
        .environment(dashboardViewModel)
        .environment(selectionStore)
        .modelContainer(for: CachedFeaturePrint.self)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                didGrantPhotos = (status == .authorized || status == .limited)
                didGrantContacts = (CNContactStore.authorizationStatus(for: .contacts) == .authorized)
                Task {
                    await dashboardViewModel.loadStorageInfo()
                }
            } else if newPhase == .background {
                Task {
                    await WidgetDataStore.shared.syncWithCurrentStorage()
                    WidgetCenter.shared.reloadTimelines(ofKind: "TidyUpStorageWidget")
                }
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "tidyup" else { return }
        if url.host == "dashboard" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let isScanReady = components?.queryItems?.first(where: { $0.name == "scan_ready" })?.value == "true"
            if isScanReady {
                dashboardViewModel.handleWidgetScanDeepLink()
            }
        }
    }
}
