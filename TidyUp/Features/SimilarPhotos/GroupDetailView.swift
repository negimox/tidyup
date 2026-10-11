import SwiftUI
import Photos

/// Displays all photos in a group; "best" shot is highlighted, others pre-selected.
struct GroupDetailView: View {
    let group: SimilarGroup
    @State private var selected: Set<String>
    @State private var showReview = false

    init(group: SimilarGroup) {
        self.group = group
        _selected = State(initialValue: Set(group.otherAssets.map { $0.localIdentifier }))
    }

    private var allAssets: [PHAsset] {
        [group.bestAsset] + group.otherAssets
    }

    private var selectedBytes: Int64 {
        group.otherAssets
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
                        GroupPhotoCell(
                            asset: asset,
                            isBest: asset.localIdentifier == group.bestAsset.localIdentifier,
                            isSelected: selected.contains(asset.localIdentifier)
                        ) {
                            toggle(asset: asset)
                        }
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
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: selected,
                allAssets: allAssets,
                contactGroups: []
            )
        }
    }

    private func toggle(asset: PHAsset) {
        let id = asset.localIdentifier
        guard id != group.bestAsset.localIdentifier else { return }
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

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                AssetThumbnail(asset: asset, size: 110)
                    .clipShape(.rect(cornerRadius: Theme.radiusCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusCard)
                            .stroke(isSelected ? Theme.deleteRed : .clear, lineWidth: 3)
                    )
                    .opacity(isBest ? 1 : (isSelected ? 0.7 : 1))

                if isBest {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Theme.bestGreen)
                        .clipShape(.circle)
                        .padding(6)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.deleteRed : .white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBest ? "Best photo, keep" : (isSelected ? "Selected for deletion" : "Not selected"))
    }
}
