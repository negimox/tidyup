import SwiftUI
import AVKit
import Photos

enum VideoSortOption: String, CaseIterable, Identifiable {
    case largest = "Largest"
    case smallest = "Smallest"
    case oldest = "Oldest"
    case newest = "Newest"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct LargeVideosListView: View {
    let items: [VideoItem]
    var onReturnToHome: (() -> Void)? = nil

    @Environment(SelectionStore.self) private var selectionStore
    @State private var previewItem: VideoItem?
    @State private var showReview = false
    @State private var selectedSort: VideoSortOption = .largest

    private var selected: Set<String> {
        selectionStore.selectedVideoIDs
    }

    private var selectedBytes: Int64 {
        items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    private var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }

    private var sortedItems: [VideoItem] {
        switch selectedSort {
        case .largest:
            return items.sorted { $0.fileSize > $1.fileSize }
        case .smallest:
            return items.sorted { $0.fileSize < $1.fileSize }
        case .newest:
            return items.sorted { ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast) }
        case .oldest:
            return items.sorted { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
        }
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
                ScrollView {
                    VStack(spacing: Theme.spacing12) {
                        // Header with video count, total size, and sort menu
                        HStack {
                            Text("\(items.count) videos · \(totalBytes, format: .byteCount(style: .file))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Menu {
                                ForEach(VideoSortOption.allCases) { option in
                                    Button {
                                        selectedSort = option
                                    } label: {
                                        HStack {
                                            Text(option.title)
                                            if selectedSort == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: Theme.spacing4) {
                                    Text(selectedSort.title)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundStyle(Theme.primary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundStyle(Theme.primary)
                                }
                                .padding(.horizontal, Theme.spacing12)
                                .padding(.vertical, Theme.spacing8)
                                .background(Theme.primary.opacity(0.1))
                                .clipShape(.capsule)
                            }
                        }
                        .padding(.horizontal, Theme.spacing4)

                        LazyVStack(spacing: Theme.spacing8) {
                            ForEach(sortedItems) { item in
                                VideoRow(
                                    item: item,
                                    isSelected: selected.contains(item.id),
                                    onToggle: { toggleSelection(item.id) },
                                    onPreview: { previewItem = item }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.top, Theme.spacing8)
                    .padding(.bottom, Theme.spacing24)
                }
            }

            if !items.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        showReview = true
                    } label: {
                        HStack(spacing: Theme.spacing8) {
                            Text("Review \(selected.count) selected")
                                .bold()
                            if selectedBytes > 0 {
                                Text("·")
                                Text(selectedBytes, format: .byteCount(style: .file))
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacing12)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(selected.isEmpty)
                    .padding(.horizontal, Theme.spacing20)
                    .padding(.vertical, Theme.spacing12)
                }
                .background(.regularMaterial)
            }
        }
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewItem) { item in
            VideoPreviewSheet(asset: item.asset)
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: selected,
                allAssets: items.map { $0.asset },
                contactGroups: [],
                onReturnToHome: {
                    selectionStore.clearVideos()
                    onReturnToHome?()
                }
            )
        }
    }

    private func toggleSelection(_ id: String) {
        selectionStore.toggleVideo(id)
    }
}

// MARK: - Row

private struct VideoRow: View {
    let item: VideoItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    private var formattedDate: String {
        guard let date = item.asset.creationDate else { return "Unknown" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var formattedDuration: String {
        Duration.seconds(Int(item.duration)).formatted(.time(pattern: .minuteSecond))
    }

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Video thumbnail with duration and play button
            Button(action: onPreview) {
                ZStack {
                    AssetThumbnail(asset: item.asset, size: 84)
                        .frame(width: 84, height: 64)
                        .clipShape(.rect(cornerRadius: Theme.radiusCard))

                    // Play icon in center
                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)

                    // Duration badge at bottom-trailing
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formattedDuration)
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .clipShape(.capsule)
                        }
                    }
                    .padding(4)
                }
                .frame(width: 84, height: 64)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview video")

            // File size & Date
            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileSize, format: .byteCount(style: .file))
                    .font(.headline)
                    .bold()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Selection toggle on right side instead of "compress"
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.deleteRed : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Deselect video" : "Select video")
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusCard))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard)
                .stroke(isSelected ? Theme.deleteRed.opacity(0.5) : Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}

// MARK: - Preview sheet

struct VideoPreviewSheet: View {
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
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat
        let box = PlayerItemResumeBox()
        let result: AVPlayerItem? = await withCheckedContinuation { cont in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                box.resume(continuation: cont, with: item)
            }
        }
        if let result {
            player = AVPlayer(playerItem: result)
            player?.play()
        }
    }
}

final class PlayerItemResumeBox: @unchecked Sendable {
    private var isResumed = false
    private let lock = NSLock()

    func resume(continuation: CheckedContinuation<AVPlayerItem?, Never>, with item: AVPlayerItem?) {
        lock.lock()
        defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        continuation.resume(returning: item)
    }
}
