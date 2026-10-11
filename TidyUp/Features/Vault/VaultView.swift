import SwiftUI
import LocalAuthentication
import PhotosUI

/// Item securely stored inside the app's private documents directory.
struct VaultItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let dateAdded: Date
    let isVideo: Bool

    init(id: UUID = UUID(), fileName: String, fileSize: Int64, dateAdded: Date = Date(), isVideo: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.isVideo = isVideo
    }
}

/// PIN or Face ID protected private vault.
struct VaultView: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    @State private var isAuthenticating = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing24) {
                if isUnlocked {
                    VaultUnlockedView()
                } else {
                    VaultLockedView(
                        authError: authError,
                        isAuthenticating: isAuthenticating,
                        onUnlock: { Task { await authenticate() } }
                    )
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lock", systemImage: "lock.fill") {
                            withAnimation { isUnlocked = false }
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    // Auto-lock when leaving foreground
                    isUnlocked = false
                }
            }
        }
    }

    // MARK: - Authentication

    private func authenticate() async {
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock your private vault"
                )
                if success {
                    withAnimation {
                        isUnlocked = true
                    }
                }
            } catch {
                authError = error.localizedDescription
            }
        } else {
            authError = error?.localizedDescription ?? "Biometrics or passcode not available."
        }

        isAuthenticating = false
    }
}

// MARK: - Subview Structs

private struct VaultLockedView: View {
    let authError: String?
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primary)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: Theme.spacing8) {
                Text("Private Vault")
                    .font(.title2)
                    .bold()

                Text("Keep sensitive photos and videos secure on your device behind Face ID.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing32)
            }

            if let authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(Theme.deleteRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing24)
            }

            Spacer()

            Button("Unlock with Biometrics", systemImage: "faceid", action: onUnlock)
                .buttonStyle(.glassProminent)
                .padding(.horizontal, Theme.spacing32)
                .padding(.bottom, Theme.spacing32)
                .disabled(isAuthenticating)
        }
    }
}

private struct VaultUnlockedView: View {
    @State private var items: [VaultItem] = []
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var viewingItem: VaultItem?

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 140), spacing: Theme.spacing8)
    ]

    private var totalVaultBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isImporting {
                VStack(spacing: Theme.spacing12) {
                    ProgressView()
                    Text("Importing to Private Vault…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            if items.isEmpty {
                VStack(spacing: Theme.spacing24) {
                    Spacer()

                    ContentUnavailableView(
                        "Vault is Empty",
                        systemImage: "lock.rectangle.stack",
                        description: Text("Items you add to the Vault are stored privately in encrypted device storage.")
                    )

                    Spacer()

                    PhotosPicker(
                        selection: $selectedPickerItems,
                        matching: .any(of: [.images, .videos]),
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: Theme.spacing8) {
                            Image(systemName: "plus")
                            Text("Add Private Items")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacing12)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, Theme.spacing32)
                    .padding(.bottom, Theme.spacing32)
                }
            } else {
                ScrollView {
                    VStack(spacing: Theme.spacing12) {
                        // Header with stats and Add button
                        HStack {
                            Text("\(items.count) private items · \(totalVaultBytes, format: .byteCount(style: .file))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            PhotosPicker(
                                selection: $selectedPickerItems,
                                matching: .any(of: [.images, .videos]),
                                photoLibrary: .shared()
                            ) {
                                HStack(spacing: Theme.spacing4) {
                                    Image(systemName: "plus")
                                    Text("Add")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, Theme.spacing12)
                                .padding(.vertical, Theme.spacing8)
                                .background(Theme.primary.opacity(0.12))
                                .foregroundStyle(Theme.primary)
                                .clipShape(.capsule)
                            }
                        }
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.top, Theme.spacing8)

                        LazyVGrid(columns: columns, spacing: Theme.spacing8) {
                            ForEach(items) { item in
                                VaultThumbnailCell(
                                    item: item,
                                    onTap: { viewingItem = item },
                                    onDelete: { delete(item) }
                                )
                            }
                        }
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.bottom, Theme.spacing24)
                    }
                }
            }
        }
        .task {
            loadItems()
        }
        .onChange(of: selectedPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importItems(newItems)
            }
        }
        .sheet(item: $viewingItem) { item in
            VaultItemViewerSheet(
                item: item,
                onDelete: {
                    delete(item)
                    viewingItem = nil
                }
            )
        }
    }

    // MARK: - File Management

    private var vaultDirectory: URL {
        let dir = URL.documentsDirectory.appending(path: "VaultFiles")
        if !FileManager.default.fileExists(atPath: dir.path()) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var manifestURL: URL {
        URL.documentsDirectory.appending(path: "vault_manifest.json")
    }

    private func loadItems() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([VaultItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func saveItems(_ newItems: [VaultItem]) {
        items = newItems
        if let encoded = try? JSONEncoder().encode(newItems) {
            try? encoded.write(to: manifestURL)
        }
    }

    private func importItems(_ pickerItems: [PhotosPickerItem]) async {
        isImporting = true
        var updated = items

        for pickerItem in pickerItems {
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self) {
                    let id = UUID()
                    let isVideo = pickerItem.supportedContentTypes.contains { $0.conforms(to: .movie) }
                    let ext = isVideo ? "mp4" : "jpg"
                    let fileName = "\(id.uuidString).\(ext)"
                    let fileURL = vaultDirectory.appending(path: fileName)

                    try data.write(to: fileURL)

                    let newItem = VaultItem(
                        id: id,
                        fileName: fileName,
                        fileSize: Int64(data.count),
                        dateAdded: Date(),
                        isVideo: isVideo
                    )
                    updated.insert(newItem, at: 0)
                }
            } catch {
                // Continue with remaining items
            }
        }

        saveItems(updated)
        selectedPickerItems.removeAll()
        isImporting = false
    }

    private func delete(_ item: VaultItem) {
        let fileURL = vaultDirectory.appending(path: item.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        let filtered = items.filter { $0.id != item.id }
        saveItems(filtered)
    }
}

// MARK: - Vault Cells and Viewer

private struct VaultThumbnailCell: View {
    let item: VaultItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: UIImage?

    private var fileURL: URL {
        URL.documentsDirectory.appending(path: "VaultFiles").appending(path: item.fileName)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 104, minHeight: 104)
                        .clipShape(.rect(cornerRadius: Theme.radiusCard))
                } else {
                    Color.secondary.opacity(0.12)
                        .frame(minWidth: 104, minHeight: 104)
                        .clipShape(.rect(cornerRadius: Theme.radiusCard))
                        .overlay {
                            Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                .foregroundStyle(.secondary)
                        }
                }

                if item.isVideo {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.7))
                        .clipShape(.circle)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete from Vault", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .task {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let img = UIImage(data: data) {
            thumbnail = img
        }
    }
}

private struct VaultItemViewerSheet: View {
    let item: VaultItem
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?

    private var fileURL: URL {
        URL.documentsDirectory.appending(path: "VaultFiles").appending(path: item.fileName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle(item.isVideo ? "Private Video" : "Private Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .task {
                if let data = try? Data(contentsOf: fileURL) {
                    fullImage = UIImage(data: data)
                }
            }
        }
    }
}
