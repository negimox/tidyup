import SwiftUI
import SwiftData
import Photos
import Contacts

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
            if didGrantPhotos || didGrantContacts {
                MainTabView()
            } else {
                PermissionsPrimerView(
                    didGrantPhotos: $didGrantPhotos,
                    didGrantContacts: $didGrantContacts
                )
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
            }
        }
    }
}
