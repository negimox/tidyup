import SwiftUI
import Photos

/// Displays all photos in a group; "best" shot is highlighted, with dedicated view preview and selection.
struct GroupDetailView: View {
    let group: SimilarGroup
    var onReturnToHome: (() -> Void)? = nil
    @State private var selected: Set<String>
    @State private var showReview = false
    @State private var previewItem: PhotoPreviewItem? = nil

    init(group: SimilarGroup, onReturnToHome: (() -> Void)? = nil) {
        self.group = group
        self.onReturnToHome = onReturnToHome
        _selected = State(initialValue: Set(group.otherAssets.map { $0.localIdentifier }))
    }

    private var allAssets: [PHAsset] {
        [group.bestAsset] + group.otherAssets
    }

    private var selectedBytes: Int64 {
        allAssets
            .filter { selected.contains($0.localIdentifier) }
            .reduce(0) { $0 + Int64($1.pixelWidth * $1.pixelHeight * 3) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.spacing8)],
                    spacing: Theme.spacing8
                ) {
                    ForEach(allAssets, id: \.localIdentifier) { asset in
                        let isBest = asset.localIdentifier == group.bestAsset.localIdentifier
                        GroupPhotoCell(
                            asset: asset,
                            isBest: isBest,
                            isSelected: selected.contains(asset.localIdentifier),
                            action: {
                                toggle(asset: asset)
                            },
                            onView: {
                                previewItem = PhotoPreviewItem(asset: asset, isBest: isBest)
                            }
                        )
                    }
                }
                .padding(Theme.spacing16)
            }

            SelectionToolbar(
                selectedCount: selected.count,
                selectedBytes: selectedBytes,
                actionTitle: "Review & Delete"
            ) {
                showReview = true
            }
        }
        .navigationTitle("Group Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewItem) { item in
            PhotoPreviewSheet(
                asset: item.asset,
                isBest: item.isBest,
                isSelected: Binding(
                    get: { selected.contains(item.asset.localIdentifier) },
                    set: { isSel in
                        if isSel {
                            selected.insert(item.asset.localIdentifier)
                        } else {
                            selected.remove(item.asset.localIdentifier)
                        }
                    }
                )
            )
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: selected,
                allAssets: allAssets,
                contactGroups: [],
                onReturnToHome: onReturnToHome
            )
        }
    }

    private func toggle(asset: PHAsset) {
        let id = asset.localIdentifier
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

// MARK: - Cell

private struct GroupPhotoCell: View {
    let asset: PHAsset
    let isBest: Bool
    let isSelected: Bool
    let action: () -> Void
    let onView: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                AssetThumbnail(asset: asset, size: 110)
                    .frame(width: 110, height: 110)
                    .clipShape(.rect(cornerRadius: Theme.radiusCard))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusCard)
                            .stroke(isSelected ? Theme.deleteRed : .clear, lineWidth: 3)
                    }
                    .opacity(isSelected ? 0.75 : 1)
            }
            .buttonStyle(.plain)

            if isBest {
                VStack {
                    HStack {
                        Text("Best")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.bestGreen)
                            .clipShape(.capsule)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
                .allowsHitTesting(false)
            }

            Button(action: action) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.deleteRed : .white)
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(6)

            // Dedicated View button
            VStack {
                Spacer()
                HStack {
                    Button(action: onView) {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                            Text("View")
                                .font(.caption2)
                                .bold()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.65))
                        .clipShape(.capsule)
                        .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo in full screen")
                    Spacer()
                }
            }
            .padding(6)
        }
        .frame(width: 110, height: 110)
        .accessibilityLabel(isBest ? "Best photo, \(isSelected ? "selected for deletion" : "kept")" : "Photo, \(isSelected ? "selected for deletion" : "kept")")
    }
}
