import SwiftUI
import AVKit
import Photos

struct LargeVideosListView: View {
    let items: [VideoItem]
    @State private var selected: Set<String> = []
    @State private var previewItem: VideoItem?
    @State private var showReview = false

    private var selectedBytes: Int64 {
        items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Large Videos",
                    systemImage: "video.badge.ellipsis",
                    description: Text("No videos found in your library.")
                )
            } else {
                List(items) { item in
                    VideoRow(
                        item: item,
                        isSelected: selected.contains(item.id),
                        onToggle: { toggleSelection(item.id) },
                        onPreview: { previewItem = item }
                    )
                }
                .listStyle(.plain)
            }

            if !items.isEmpty {
                SelectionToolbar(
                    selectedCount: selected.count,
                    selectedBytes: selectedBytes,
                    actionTitle: "Review & Delete"
                ) {
                    showReview = true
                }
            }
        }
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $previewItem) { item in
            VideoPreviewSheet(asset: item.asset)
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: selected,
                allAssets: items.map { $0.asset },
                contactGroups: []
            )
        }
    }

    private func toggleSelection(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}

// MARK: - Row

private struct VideoRow: View {
    let item: VideoItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Checkmark
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.deleteRed : .secondary)
            }
            .buttonStyle(.plain)

            // Thumbnail + play
            Button(action: onPreview) {
                ZStack {
                    AssetThumbnail(asset: item.asset, size: 70)
                        .clipShape(.rect(cornerRadius: Theme.radiusCard))
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
                .frame(width: 70, height: 70)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview video")

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(item.fileSize, format: .byteCount(style: .file))
                    .font(.headline)
                Text(Duration.seconds(item.duration), format: .units(width: .abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let date = item.asset.creationDate {
                    Text(date, format: .dateTime.month().day().year())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, Theme.spacing8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview sheet

private struct VideoPreviewSheet: View {
    let asset: PHAsset
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView("Loading video…")
                    .task { await loadPlayer() }
            }
        }
    }

    private func loadPlayer() async {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat
        let result: AVPlayerItem? = await withCheckedContinuation { cont in
            var resumed = false
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: item)
            }
        }
        if let result {
            player = AVPlayer(playerItem: result)
            player?.play()
        }
    }
}
