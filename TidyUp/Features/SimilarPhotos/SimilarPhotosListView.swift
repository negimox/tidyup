import SwiftUI
import Photos

enum SimilarSortOption: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case largest = "Largest"
    case smallest = "Smallest"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// Shows similar-photo groups according to Figma Page 4 design.
/// Each group is a card containing a horizontal scroll of photos with "Best" badge,
/// per-photo deletion selection toggle, dedicated "View" preview button,
/// "Keep best" / "Unselect" toggle button, and sticky review bottom bar.
struct SimilarPhotosListView: View {
    let groups: [SimilarGroup]
    var onReturnToHome: (() -> Void)? = nil

    @Environment(SelectionStore.self) private var selectionStore
    @State private var showReview = false
    @State private var selectedGroupForDetail: SimilarGroup? = nil
    @State private var previewItem: PhotoPreviewItem? = nil
    @State private var selectedSort: SimilarSortOption = .newest

    init(groups: [SimilarGroup], onReturnToHome: (() -> Void)? = nil) {
        self.groups = groups
        self.onReturnToHome = onReturnToHome
    }

    private var selectedPhotoIDs: Set<String> {
        selectionStore.selectedSimilarPhotoIDs
    }

    private var selectedPhotoIDsBinding: Binding<Set<String>> {
        Binding(
            get: { selectionStore.selectedSimilarPhotoIDs },
            set: { selectionStore.selectedSimilarPhotoIDs = $0 }
        )
    }

    private var allAssets: [PHAsset] {
        groups.flatMap { [$0.bestAsset] + $0.otherAssets }
    }

    private var selectedBytes: Int64 {
        allAssets
            .filter { selectedPhotoIDs.contains($0.localIdentifier) }
            .reduce(0) { $0 + Int64($1.pixelWidth * $1.pixelHeight * 3) }
    }

    private var totalSavings: Int64 {
        groups.reduce(0) { $0 + $1.estimatedSavings }
    }

    private var sortedGroups: [SimilarGroup] {
        switch selectedSort {
        case .newest:
            return groups.sorted { ($0.bestAsset.creationDate ?? .distantPast) > ($1.bestAsset.creationDate ?? .distantPast) }
        case .oldest:
            return groups.sorted { ($0.bestAsset.creationDate ?? .distantPast) < ($1.bestAsset.creationDate ?? .distantPast) }
        case .largest:
            return groups.sorted { $0.estimatedSavings > $1.estimatedSavings }
        case .smallest:
            return groups.sorted { $0.estimatedSavings < $1.estimatedSavings }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Similar Photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Your library looks unique!")
                )
            } else {
                // Scrollable content with header description inside so it stretches on overscroll
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacing16) {
                        // Header description with the title and sort menu
                        HStack {
                            Text("\(groups.count) groups · \(totalSavings, format: .byteCount(style: .file)) can be freed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Menu {
                                ForEach(SimilarSortOption.allCases) { option in
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

                        ForEach(sortedGroups) { group in
                            SimilarGroupCard(
                                group: group,
                                selectedPhotoIDs: selectedPhotoIDsBinding,
                                onInspect: {
                                    selectedGroupForDetail = group
                                },
                                onViewAsset: { asset, isBest in
                                    previewItem = PhotoPreviewItem(asset: asset, isBest: isBest)
                                }
                            )
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
                        showReview = true
                    } label: {
                        HStack(spacing: Theme.spacing8) {
                            Text("Review \(selectedPhotoIDs.count) selected")
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
                    .disabled(selectedPhotoIDs.isEmpty)
                    .padding(.horizontal, Theme.spacing20)
                    .padding(.vertical, Theme.spacing12)
                }
                .background(.regularMaterial)
            }
        }
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewItem) { item in
            PhotoPreviewSheet(
                asset: item.asset,
                isBest: item.isBest,
                isSelected: Binding(
                    get: { selectionStore.selectedSimilarPhotoIDs.contains(item.asset.localIdentifier) },
                    set: { selected in
                        if selected {
                            selectionStore.selectedSimilarPhotoIDs.insert(item.asset.localIdentifier)
                        } else {
                            selectionStore.selectedSimilarPhotoIDs.remove(item.asset.localIdentifier)
                        }
                    }
                )
            )
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: selectedPhotoIDs,
                allAssets: allAssets,
                contactGroups: [],
                onReturnToHome: {
                    selectionStore.clearSimilarPhotos()
                    onReturnToHome?()
                }
            )
        }
        .navigationDestination(item: $selectedGroupForDetail) { group in
            GroupDetailView(
                group: group,
                onReturnToHome: onReturnToHome
            )
        }
    }
}

// MARK: - Group Card

private struct SimilarGroupCard: View {
    let group: SimilarGroup
    @Binding var selectedPhotoIDs: Set<String>
    let onInspect: () -> Void
    let onViewAsset: (PHAsset, Bool) -> Void

    private var allGroupAssets: [PHAsset] {
        [group.bestAsset] + group.otherAssets
    }

    private var formattedDate: String {
        guard let date = group.bestAsset.creationDate else { return "Similar photos" }
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// True if any photo in this group is currently selected for deletion.
    private var hasGroupSelection: Bool {
        allGroupAssets.contains { selectedPhotoIDs.contains($0.localIdentifier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            // Horizontal scrollable photos
            ScrollView(.horizontal) {
                LazyHStack(spacing: Theme.spacing8) {
                    ForEach(allGroupAssets, id: \.localIdentifier) { asset in
                        let isBest = asset.localIdentifier == group.bestAsset.localIdentifier
                        let isSelected = selectedPhotoIDs.contains(asset.localIdentifier)
                        SimilarPhotoItem(
                            asset: asset,
                            isBest: isBest,
                            isSelected: isSelected,
                            onToggle: {
                                toggle(asset.localIdentifier)
                            },
                            onView: {
                                onViewAsset(asset, isBest)
                            }
                        )
                    }
                }
                .padding(.horizontal, Theme.spacing16)
            }
            .scrollIndicators(.hidden)

            // Card footer
            HStack(alignment: .center) {
                Button(action: onInspect) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.spacing4) {
                            Text("\(allGroupAssets.count) similar photos")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(formattedDate) · Save \(group.estimatedSavings, format: .byteCount(style: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: toggleKeepBest) {
                    Text(hasGroupSelection ? "Unselect" : "Keep best")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, Theme.spacing12)
                        .padding(.vertical, Theme.spacing8)
                        .background(hasGroupSelection ? Color.secondary.opacity(0.12) : Theme.primary.opacity(0.12))
                        .foregroundStyle(hasGroupSelection ? Color.primary : Theme.primary)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasGroupSelection ? "Deselect all photos in this group" : "Keep best photo and select duplicates for deletion")
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.bottom, Theme.spacing16)
        }
        .padding(.top, Theme.spacing16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusSheet)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func toggle(_ id: String) {
        if selectedPhotoIDs.contains(id) {
            selectedPhotoIDs.remove(id)
        } else {
            selectedPhotoIDs.insert(id)
        }
    }

    private func toggleKeepBest() {
        if hasGroupSelection {
            // Deselect all selections in this group
            for asset in allGroupAssets {
                selectedPhotoIDs.remove(asset.localIdentifier)
            }
        } else {
            // Select all other assets except bestAsset
            selectedPhotoIDs.remove(group.bestAsset.localIdentifier)
            for asset in group.otherAssets {
                selectedPhotoIDs.insert(asset.localIdentifier)
            }
        }
    }
}

// MARK: - Photo Item

private struct SimilarPhotoItem: View {
    let asset: PHAsset
    let isBest: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onView: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Whole thumbnail can be tapped to toggle selection
            Button(action: onToggle) {
                AssetThumbnail(asset: asset, size: 110)
                    .frame(width: 110, height: 110)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Theme.deleteRed : Color.clear, lineWidth: 2)
                    }
                    .opacity(isSelected ? 0.75 : 1.0)
            }
            .buttonStyle(.plain)

            // "Best" badge at top-left
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

            // Selection checkmark at top-right
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? Theme.deleteRed : Color.white)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white : Color.black.opacity(0.35))
                            .frame(width: 16, height: 16)
                    )
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .frame(width: 110, height: 110)
        .overlay(alignment: .bottomLeading) {
            Button(action: onView) {
                HStack(spacing: 3) {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                    Text("View")
                        .font(.caption2)
                        .bold()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .clipShape(.capsule)
                .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    onView()
                }
            )
            .padding(6)
            .accessibilityLabel("View photo in full screen")
        }
    }
}

// MARK: - Preview Sheet & Item

struct PhotoPreviewItem: Identifiable {
    let id: String
    let asset: PHAsset
    let isBest: Bool

    init(asset: PHAsset, isBest: Bool) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.isBest = isBest
    }
}

struct PhotoPreviewSheet: View {
    let asset: PHAsset
    let isBest: Bool
    @Binding var isSelected: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea(edges: .bottom)
                } else if isLoading {
                    ProgressView("Loading photo…")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else {
                    ContentUnavailableView(
                        "Unable to Load Photo",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("The full-resolution photo could not be retrieved.")
                    )
                }
            }
            .navigationTitle(isBest ? "Best Photo" : "Similar Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSelected.toggle()
                    } label: {
                        HStack(spacing: Theme.spacing4) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text(isSelected ? "Selected" : "Select")
                        }
                    }
                    .tint(isSelected ? Theme.deleteRed : .white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Theme.spacing8) {
                    HStack {
                        if isBest {
                            Text("Best Pick")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.spacing8)
                                .padding(.vertical, Theme.spacing4)
                                .background(Theme.bestGreen)
                                .clipShape(.capsule)
                        }

                        if let date = asset.creationDate {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Spacer()

                        Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, Theme.spacing20)
                .padding(.vertical, Theme.spacing12)
                .background(.ultraThinMaterial)
            }
            .task {
                await loadHighResImage()
            }
        }
    }

    @MainActor
    private func loadHighResImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .none

        let targetSize = CGSize(
            width: max(asset.pixelWidth, 1024),
            height: max(asset.pixelHeight, 1024)
        )

        let stream = AsyncStream<UIImage?> { continuation in
            let reqID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { img, info in
                if let img {
                    continuation.yield(img)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                if !isDegraded || isCancelled || hasError || img == nil {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                PHImageManager.default().cancelImageRequest(reqID)
            }
        }

        for await img in stream {
            if let img {
                self.fullImage = img
                self.isLoading = false
            }
        }
        self.isLoading = false
    }
}

