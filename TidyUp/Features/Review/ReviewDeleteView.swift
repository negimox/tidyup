import SwiftUI
import Photos

/// Final review screen before any deletions occur.
struct ReviewDeleteView: View {
    let selectedPhotoIDs: Set<String>
    let allAssets: [PHAsset]
    let contactGroups: [DuplicateContactGroup]

    var onReturnToHome: (() -> Void)? = nil

    @State private var viewModel = ReviewViewModel()
    @State private var showSpaceFreed = false

    private var selectedAssets: [PHAsset] {
        allAssets.filter { selectedPhotoIDs.contains($0.localIdentifier) }
    }

    private var selectedPhotoBytes: Int64 {
        selectedAssets.reduce(0) { $0 + Int64($1.pixelWidth * $1.pixelHeight * 3) }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                if !selectedAssets.isEmpty {
                    Section("Photos & Videos") {
                        HStack {
                            Text("\(selectedAssets.count) items")
                            Spacer()
                            Text(selectedPhotoBytes, format: .byteCount(style: .file))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Label(
                            "These items will move to Recently Deleted. You have 30 days to recover them.",
                            systemImage: "trash"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if !contactGroups.isEmpty {
                    Section("Contacts") {
                        HStack {
                            Text("\(contactGroups.count) group\(contactGroups.count == 1 ? "" : "s") to merge")
                            Spacer()
                        }
                    }

                    Section {
                        Label(
                            "Contact merges are permanent and cannot be undone from the app.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.deleteRed)
                    }
                }

                Section("Summary") {
                    if selectedPhotoBytes > 0 {
                        HStack {
                            Text("Estimated space freed")
                            Spacer()
                            Text(selectedPhotoBytes, format: .byteCount(style: .file))
                                .foregroundStyle(Theme.bestGreen)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Confirm CTA
            VStack(spacing: Theme.spacing12) {
                if viewModel.isDeleting {
                    ProgressView("Deleting…")
                } else {
                    let totalItems = selectedAssets.count + contactGroups.count
                    Button(totalItems > 0 ? "Delete \(totalItems) items" : "Confirm & Clean", systemImage: "trash.fill") {
                        Task {
                            await viewModel.performDeletion(
                                assets: selectedAssets,
                                contactGroups: contactGroups
                            )
                            if viewModel.error == nil {
                                showSpaceFreed = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.deleteRed)
                    .controlSize(.large)
                    .disabled(selectedAssets.isEmpty && contactGroups.isEmpty)
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Theme.deleteRed)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.spacing20)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSpaceFreed) {
            SpaceFreedView(
                itemCount: selectedAssets.count,
                contactsMerged: contactGroups.count,
                freedBytes: selectedPhotoBytes,
                onReturnToHome: onReturnToHome
            )
        }
    }
}
