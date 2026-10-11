import SwiftUI
import SwiftData
import Photos

struct DashboardView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(SelectionStore.self) private var selectionStore

    // Navigation destinations
    @State private var showSimilarPhotos = false
    @State private var showScreenshots = false
    @State private var showVideos = false
    @State private var showContacts = false
    @State private var showReviewAll = false
    @State private var showRecycleBin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    DashboardStorageCard(
                        usedBytes: viewModel.usedBytes,
                        totalBytes: viewModel.totalBytes
                    )

                    if let scanResult = viewModel.scanResult {
                        DashboardFreeableBanner(
                            freeableBytes: scanResult.totalFreeable,
                            onRescan: {
                                selectionStore.clearAll()
                                viewModel.startScan(modelContainer: modelContext.container)
                            }
                        )

                        DashboardCategoriesSection(
                            scanResult: scanResult,
                            isScanning: isScanning,
                            selectionStore: selectionStore,
                            onSelectSimilar: { showSimilarPhotos = true },
                            onSelectScreenshots: { showScreenshots = true },
                            onSelectVideos: { showVideos = true },
                            onSelectContacts: { showContacts = true }
                        )
                    } else {
                        DashboardScanSection(
                            scanState: viewModel.scanState,
                            onScan: {
                                selectionStore.clearAll()
                                viewModel.startScan(modelContainer: modelContext.container)
                            },
                            onCancel: { viewModel.cancelScan() }
                        )
                    }

                    DashboardRecycleBinCard {
                        showRecycleBin = true
                    }
                }
                .padding(.horizontal, Theme.spacing20)
                .padding(.top, Theme.spacing20)
                .padding(.bottom, Theme.spacing48)
            }
            .safeAreaInset(edge: .bottom) {
                if selectionStore.hasSelections {
                    VStack(spacing: 0) {
                        Divider()
                        Button {
                            showReviewAll = true
                        } label: {
                            HStack(spacing: Theme.spacing8) {
                                Text("Review \(selectionStore.totalSelectedCount) selected")
                                    .bold()
                                let totalBytes = selectionStore.totalSelectedBytes(from: viewModel.scanResult)
                                if totalBytes > 0 {
                                    Text("·")
                                    Text(totalBytes, format: .byteCount(style: .file))
                                        .bold()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacing12)
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.horizontal, Theme.spacing20)
                        .padding(.vertical, Theme.spacing12)
                    }
                    .background(.regularMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectionStore.totalSelectedCount)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Recycle Bin", systemImage: "trash") {
                        showRecycleBin = true
                    }
                    .accessibilityLabel("Open Recycle Bin")
                }
            }
            .sheet(isPresented: $showRecycleBin) {
                RecycleBinSheet()
            }
            .task { await viewModel.loadStorageInfo() }
            .navigationDestination(isPresented: $showSimilarPhotos) {
                if let result = viewModel.scanResult {
                    SimilarPhotosListView(
                        groups: result.similarGroups,
                        onReturnToHome: returnToHomeAndRescan
                    )
                }
            }
            .navigationDestination(isPresented: $showScreenshots) {
                if let result = viewModel.scanResult {
                    ScreenshotsGridView(
                        items: result.screenshots,
                        onReturnToHome: returnToHomeAndRescan
                    )
                }
            }
            .navigationDestination(isPresented: $showVideos) {
                if let result = viewModel.scanResult {
                    LargeVideosListView(
                        items: result.videos,
                        onReturnToHome: returnToHomeAndRescan
                    )
                }
            }
            .navigationDestination(isPresented: $showContacts) {
                if let result = viewModel.scanResult {
                    DuplicateContactsView(
                        groups: result.duplicateContacts,
                        onReturnToHome: returnToHomeAndRescan
                    )
                }
            }
            .navigationDestination(isPresented: $showReviewAll) {
                ReviewDeleteView(
                    selectedPhotoIDs: selectionStore.allSelectedPhotoIDs,
                    allAssets: allScannedAssets,
                    contactGroups: selectedContactGroups,
                    onReturnToHome: {
                        selectionStore.clearAll()
                        returnToHomeAndRescan()
                    }
                )
            }
        }
    }

    private func returnToHomeAndRescan() {
        showSimilarPhotos = false
        showScreenshots = false
        showVideos = false
        showContacts = false
        showReviewAll = false
        selectionStore.clearAll()
        viewModel.startScan(modelContainer: modelContext.container)
    }

    private var allScannedAssets: [PHAsset] {
        guard let result = viewModel.scanResult else { return [] }
        let similarAssets = result.similarGroups.flatMap { [$0.bestAsset] + $0.otherAssets }
        let screenshotAssets = result.screenshots.map { $0.asset }
        let videoAssets = result.videos.map { $0.asset }
        return similarAssets + screenshotAssets + videoAssets
    }

    private var selectedContactGroups: [DuplicateContactGroup] {
        guard let result = viewModel.scanResult else { return [] }
        return result.duplicateContacts.filter { selectionStore.selectedContactGroupIDs.contains($0.id) }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.scanState { return true }
        return false
    }
}

// MARK: - Subview Structs

private struct DashboardStorageCard: View {
    let usedBytes: Int64
    let totalBytes: Int64

    private var freeBytes: Int64 {
        max(0, totalBytes - usedBytes)
    }

    var body: some View {
        HStack(spacing: Theme.spacing24) {
            StorageRingView(usedBytes: usedBytes, totalBytes: totalBytes)

            VStack(alignment: .leading, spacing: Theme.spacing12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(usedBytes, format: .byteCount(style: .file))
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("of \(totalBytes.formatted(.byteCount(style: .file)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(freeBytes, format: .byteCount(style: .file))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Theme.bestGreen)
                        .contentTransition(.numericText())
                }
            }

            Spacer()
        }
        .padding(Theme.spacing20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusSheet)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}

private struct DashboardFreeableBanner: View {
    let freeableBytes: Int64
    let onRescan: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("You can free up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(freeableBytes, format: .byteCount(style: .file))
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button(action: onRescan) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                    Text("Rescan")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, Theme.spacing8)
                .background(Theme.primary)
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rescan storage")
        }
        .padding(.horizontal, Theme.spacing20)
        .padding(.vertical, Theme.spacing16)
        .background(Theme.primary.opacity(0.08))
        .clipShape(.rect(cornerRadius: Theme.radiusCard))
    }
}

private struct DashboardScanSection: View {
    let scanState: DashboardViewModel.ScanState
    let onScan: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing20) {
            switch scanState {
            case .idle:
                VStack(spacing: Theme.spacing20) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(spacing: Theme.spacing8) {
                        Text("Analyze Storage")
                            .font(.title3)
                            .bold()
                        Text("Scan your photo library and contacts to find duplicate photos, large videos, and screenshots.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.spacing16)
                    }

                    Button {
                        onScan()
                    } label: {
                        HStack(spacing: Theme.spacing8) {
                            Image(systemName: "sparkles")
                                .font(.headline)
                            Text("Scan Storage")
                                .font(.headline)
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacing16)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, Theme.spacing8)
                    .accessibilityHint("Scans your photos, videos, and contacts for items you can delete")
                }

            case .scanning(let message, let progress):
                VStack(spacing: Theme.spacing16) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.primary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Cancel", systemImage: "xmark.circle", action: onCancel)
                        .buttonStyle(.glass)
                }

            case .done:
                EmptyView()
            }
        }
        .padding(Theme.spacing24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusSheet)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}

private struct DashboardCategoriesSection: View {
    let scanResult: ScanResult
    let isScanning: Bool
    let selectionStore: SelectionStore
    let onSelectSimilar: () -> Void
    let onSelectScreenshots: () -> Void
    let onSelectVideos: () -> Void
    let onSelectContacts: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing12) {
            CategoryRowView(
                icon: "photo.on.rectangle.angled",
                title: "Similar Photos",
                color: Theme.photosColor,
                itemCount: scanResult.similarGroups.count,
                savingsBytes: scanResult.similarGroups.reduce(0) { $0 + $1.estimatedSavings },
                isScanning: isScanning,
                selectedCount: selectionStore.similarPhotosCount,
                selectedBytes: selectionStore.similarPhotosBytes(from: scanResult),
                unit: "groups",
                action: onSelectSimilar
            )

            CategoryRowView(
                icon: "camera.viewfinder",
                title: "Screenshots",
                color: Theme.screensColor,
                itemCount: scanResult.screenshots.count,
                savingsBytes: scanResult.screenshots.reduce(0) { $0 + $1.fileSize },
                isScanning: isScanning,
                selectedCount: selectionStore.screenshotsCount,
                selectedBytes: selectionStore.screenshotsBytes(from: scanResult),
                unit: "items",
                action: onSelectScreenshots
            )

            CategoryRowView(
                icon: "video.badge.ellipsis",
                title: "Large Videos",
                color: Theme.videosColor,
                itemCount: scanResult.videos.count,
                savingsBytes: scanResult.videos.reduce(0) { $0 + $1.fileSize },
                isScanning: isScanning,
                selectedCount: selectionStore.videosCount,
                selectedBytes: selectionStore.videosBytes(from: scanResult),
                unit: "videos",
                action: onSelectVideos
            )

            CategoryRowView(
                icon: "person.2.badge.gearshape",
                title: "Duplicate Contacts",
                color: Theme.contactsColor,
                itemCount: scanResult.duplicateContacts.count,
                savingsBytes: 0,
                isScanning: isScanning,
                selectedCount: selectionStore.contactsCount,
                selectedBytes: 0,
                unit: "groups",
                action: onSelectContacts
            )
        }
    }
}

private struct DashboardRecycleBinCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.deleteRed.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundStyle(Theme.deleteRed)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recycle Bin")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Clear recently deleted items in Photos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.spacing16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: Theme.radiusSheet))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusSheet)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recycle Bin, clear recently deleted items in Photos")
    }
}
