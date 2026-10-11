import SwiftUI
import Photos

/// Shows all similar-photo groups; tapping drills into GroupDetailView.
struct SimilarPhotosListView: View {
    let groups: [SimilarGroup]

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Similar Photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Your library looks unique!")
                )
            } else {
                List(groups) { group in
                    NavigationLink(value: group) {
                        SimilarGroupRow(group: group)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SimilarGroup.self) { group in
            GroupDetailView(group: group)
        }
    }
}

// MARK: - Row

private struct SimilarGroupRow: View {
    let group: SimilarGroup

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            AssetThumbnail(asset: group.bestAsset, size: 60)
                .clipShape(.rect(cornerRadius: Theme.radiusCard))
                .overlay(alignment: .topLeading) {
                    Text("BEST")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.bestGreen)
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(4)
                }

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text("\(group.otherAssets.count + 1) photos")
                    .font(.headline)
                Text("Save \(group.estimatedSavings, format: .byteCount(style: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Theme.spacing8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Group of \(group.otherAssets.count + 1) similar photos, saves \(group.estimatedSavings, format: .byteCount(style: .file))")
    }
}
