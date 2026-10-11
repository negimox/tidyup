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
        .modelContainer(for: CachedFeaturePrint.self)
    }
}
