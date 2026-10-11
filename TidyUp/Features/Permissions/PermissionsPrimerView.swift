import SwiftUI
import Photos
import Contacts

/// Explains permissions before requesting them; handles all authorization states.
struct PermissionsPrimerView: View {
    @Binding var didGrantPhotos: Bool
    @Binding var didGrantContacts: Bool

    @State private var photosStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var contactsStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var isRequesting = false

    private let permissionService = PermissionService()

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing32) {
                Spacer()

                // App Icon placeholder
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.primary)

                Text("TidyUp needs a few permissions to scan your device.")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing32)

                // Permission cards
                VStack(spacing: Theme.spacing12) {
                    PermissionCard(
                        icon: "photo.on.rectangle.angled",
                        title: "Photos Library",
                        description: "To find similar, duplicate, and large media.",
                        color: Theme.photosColor,
                        status: photosStatusLabel
                    )

                    PermissionCard(
                        icon: "person.crop.circle",
                        title: "Contacts",
                        description: "To detect and merge duplicate contacts.",
                        color: Theme.contactsColor,
                        status: contactsStatusLabel
                    )
                }
                .padding(.horizontal, Theme.spacing20)

                Spacer()

                // CTA
                if isRequesting {
                    ProgressView()
                } else {
                    Button("Allow Access", systemImage: "lock.open.fill") {
                        Task { await requestPermissions() }
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, Theme.spacing32)
                }

                // Limited Photos banner
                if photosStatus == .limited {
                    Button("Expand Photo Selection…") {
                        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: UIViewController())
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                }

                // Settings deep-link
                if photosStatus == .denied || contactsStatus == .denied {
                    Button("Open Settings to enable access", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.spacing32)
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func requestPermissions() async {
        isRequesting = true

        let photosResult = await permissionService.requestPhotosAccess()
        photosStatus = photosResult
        didGrantPhotos = photosResult == .authorized || photosResult == .limited

        let contactsResult = await permissionService.requestContactsAccess()
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        didGrantContacts = contactsResult

        isRequesting = false
    }

    private var photosStatusLabel: String {
        switch photosStatus {
        case .authorized: "Full access"
        case .limited: "Limited access"
        case .denied, .restricted: "Denied"
        default: "Not determined"
        }
    }

    private var contactsStatusLabel: String {
        switch contactsStatus {
        case .authorized: "Full access"
        case .denied, .restricted: "Denied"
        default: "Not determined"
        }
    }
}

// MARK: - Card

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let status: String

    var body: some View {
        HStack(spacing: Theme.spacing16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusCard))

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
            Spacer()
        }
        .padding(Theme.spacing16)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusCard))
    }

    private var statusColor: Color {
        if status.contains("Full") { return Theme.bestGreen }
        if status.contains("Limited") { return Theme.videosColor }
        if status.contains("Denied") { return Theme.deleteRed }
        return .secondary
    }
}
