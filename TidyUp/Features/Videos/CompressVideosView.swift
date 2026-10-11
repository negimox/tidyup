import SwiftUI
import Photos
import AVKit

struct CompressVideosView: View {
    @Environment(DashboardViewModel.self) private var dashboardViewModel
    @State private var selectedVideoIDs: Set<String> = []
    @State private var previewItem: VideoItem?
    @State private var selectedSort: VideoSortOption = .newest

    // Compression State
    @State private var isCompressing = false
    @State private var compressionCurrentIndex = 0
    @State private var compressionTotalCount = 0
    @State private var compressionProgress: Double = 0.0
    @State private var compressionStatusMessage: String = ""
    @State private var compressionTask: Task<Void, Never>? = nil

    // Success / Result state
    @State private var showResultAlert = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""
    @State private var compressedVideoIDs: Set<String> = []

    private var allVideos: [VideoItem] {
        dashboardViewModel.scanResult?.videos ?? []
    }

    /// Exclude already compressed videos from active view
    private var availableVideos: [VideoItem] {
        allVideos.filter { !compressedVideoIDs.contains($0.id) }
    }

    private var totalPotentialSavings: Int64 {
        availableVideos.reduce(0) { $0 + max(0, $1.fileSize * 6 / 10) }
    }

    private var selectedSavings: Int64 {
        availableVideos
            .filter { selectedVideoIDs.contains($0.id) }
            .reduce(0) { $0 + max(0, $1.fileSize * 6 / 10) }
    }

    private var sortedVideos: [VideoItem] {
        switch selectedSort {
        case .newest:
            return availableVideos.sorted { ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast) }
        case .oldest:
            return availableVideos.sorted { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
        case .largest:
            return availableVideos.sorted { $0.fileSize > $1.fileSize }
        case .smallest:
            return availableVideos.sorted { $0.fileSize < $1.fileSize }
        }
    }

    private var allSelected: Bool {
        !availableVideos.isEmpty && selectedVideoIDs.count == availableVideos.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availableVideos.isEmpty {
                    ContentUnavailableView(
                        "No Videos to Compress",
                        systemImage: "checkmark.seal.fill",
                        description: Text(compressedVideoIDs.isEmpty ? "No large videos found in your scan." : "All selected videos have been compressed successfully!")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Theme.spacing12) {
                            // Header with stats, select all, and sort menu
                            HStack {
                                Text("\(availableVideos.count) videos · Save up to ~\(totalPotentialSavings, format: .byteCount(style: .file))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    toggleSelectAll()
                                } label: {
                                    Text(allSelected ? "Deselect All" : "Select All")
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, Theme.spacing12)
                                        .padding(.vertical, Theme.spacing8)
                                        .background(Color.secondary.opacity(0.12))
                                        .foregroundStyle(.primary)
                                        .clipShape(.capsule)
                                }

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
                                ForEach(sortedVideos) { item in
                                    CompressVideoRow(
                                        item: item,
                                        isSelected: selectedVideoIDs.contains(item.id),
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

                    // Sticky Bottom Bar
                    VStack(spacing: 0) {
                        Divider()
                        Button {
                            startBatchCompression()
                        } label: {
                            HStack(spacing: Theme.spacing8) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text("Compress \(selectedVideoIDs.count) selected")
                                    .bold()
                                if selectedSavings > 0 {
                                    Text("·")
                                    Text("Save ~\(selectedSavings, format: .byteCount(style: .file))")
                                        .bold()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacing12)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(selectedVideoIDs.isEmpty || isCompressing)
                        .padding(.horizontal, Theme.spacing20)
                        .padding(.vertical, Theme.spacing12)
                    }
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("Compress Videos")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $previewItem) { item in
                VideoPreviewSheet(asset: item.asset)
            }
            .sheet(isPresented: $isCompressing) {
                CompressionProgressModal(
                    currentIndex: compressionCurrentIndex,
                    totalCount: compressionTotalCount,
                    progress: compressionProgress,
                    statusMessage: compressionStatusMessage,
                    onCancel: cancelCompression
                )
                .interactiveDismissDisabled()
            }
            .alert(resultAlertTitle, isPresented: $showResultAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resultAlertMessage)
            }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedVideoIDs.contains(id) {
            selectedVideoIDs.remove(id)
        } else {
            selectedVideoIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedVideoIDs.removeAll()
        } else {
            selectedVideoIDs = Set(availableVideos.map { $0.id })
        }
    }

    private func startBatchCompression() {
        let targets = availableVideos.filter { selectedVideoIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        compressionTotalCount = targets.count
        compressionCurrentIndex = 0
        compressionProgress = 0.0
        compressionStatusMessage = "Preparing compression…"
        isCompressing = true

        compressionTask = Task {
            let service = VideoCompressionService()
            var succeededIDs: Set<String> = []
            var totalBytesSaved: Int64 = 0

            for (index, video) in targets.enumerated() {
                guard !Task.isCancelled else { break }

                compressionCurrentIndex = index + 1
                compressionProgress = Double(index) / Double(targets.count)
                compressionStatusMessage = "Compressing video \(index + 1) of \(targets.count)…"

                do {
                    let result = try await service.compress(asset: video.asset)
                    let saved = max(0, video.fileSize - result.compressedSize)
                    totalBytesSaved += saved
                    succeededIDs.insert(video.id)
                } catch {
                    // Continue with next video if one fails
                }
            }

            guard !Task.isCancelled else {
                isCompressing = false
                return
            }

            isCompressing = false

            // Update state
            for id in succeededIDs {
                compressedVideoIDs.insert(id)
                selectedVideoIDs.remove(id)
            }

            // Refresh storage capacity in background
            await dashboardViewModel.loadStorageInfo()

            let formattedSaved = totalBytesSaved.formatted(.byteCount(style: .file))
            if succeededIDs.count == targets.count {
                resultAlertTitle = "Compression Complete"
                resultAlertMessage = "Successfully compressed \(succeededIDs.count) \(succeededIDs.count == 1 ? "video" : "videos") to 720p HD. Reclaimed ~\(formattedSaved) of storage!"
            } else if !succeededIDs.isEmpty {
                resultAlertTitle = "Partially Completed"
                resultAlertMessage = "Compressed \(succeededIDs.count) of \(targets.count) videos. Reclaimed ~\(formattedSaved)!"
            } else {
                resultAlertTitle = "Compression Failed"
                resultAlertMessage = "Unable to compress the selected videos. Please ensure sufficient temporary storage is available."
            }
            showResultAlert = true
        }
    }

    private func cancelCompression() {
        compressionTask?.cancel()
        compressionTask = nil
        isCompressing = false
    }
}

// MARK: - Video Row

private struct CompressVideoRow: View {
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

    private var estimatedSaved: Int64 {
        max(0, item.fileSize * 6 / 10)
    }

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            // Thumbnail with duration & play button
            Button(action: onPreview) {
                ZStack {
                    AssetThumbnail(asset: item.asset, size: 84)
                        .frame(width: 84, height: 64)
                        .clipShape(.rect(cornerRadius: Theme.radiusCard))

                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)

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

            // Size, estimated savings pill, and date
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileSize, format: .byteCount(style: .file))
                    .font(.headline)
                    .bold()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.caption2)
                    Text("Save ~\(estimatedSaved, format: .byteCount(style: .file))")
                        .font(.caption)
                        .bold()
                }
                .foregroundStyle(Theme.bestGreen)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Selection toggle on right side
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.primary : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Deselect video for compression" : "Select video for compression")
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusCard))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard)
                .stroke(isSelected ? Theme.primary.opacity(0.5) : Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}

// MARK: - Progress Modal

private struct CompressionProgressModal: View {
    let currentIndex: Int
    let totalCount: Int
    let progress: Double
    let statusMessage: String
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.primary)
                }

                VStack(spacing: Theme.spacing8) {
                    Text("Compressing Videos")
                        .font(.title2)
                        .bold()
                    Text("Re-encoding selected videos to 720p HD to reclaim storage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacing20)
                }

                VStack(spacing: Theme.spacing12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.primary)

                    HStack {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(currentIndex) / \(totalCount)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Theme.spacing16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: Theme.radiusCard))
                .padding(.horizontal, Theme.spacing20)

                Spacer()

                Button("Cancel", systemImage: "xmark.circle", action: onCancel)
                    .buttonStyle(.glass)
                    .padding(.bottom, Theme.spacing20)
            }
            .navigationTitle("Compress")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
