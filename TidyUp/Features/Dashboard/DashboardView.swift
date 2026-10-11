import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext

    // Navigation destinations
    @State private var showSimilarPhotos = false
    @State private var showScreenshots = false
    @State private var showVideos = false
    @State private var showContacts = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing24) {
                    DashboardStorageSection(
                        usedBytes: viewModel.usedBytes,
                        totalBytes: viewModel.totalBytes,
                        freeableBytes: viewModel.scanResult?.totalFreeable ?? 0
                    )

                    DashboardScanControls(
                        scanState: viewModel.scanState,
                        onScan: { viewModel.startScan(modelContainer: modelContext.container) },
                        onCancel: { viewModel.cancelScan() }
                    )

                    DashboardCategoriesSection(
                        scanResult: viewModel.scanResult,
                        isScanning: isScanning,
                        onSelectSimilar: { showSimilarPhotos = true },
                        onSelectScreenshots: { showScreenshots = true },
                        onSelectVideos: { showVideos = true },
                        onSelectContacts: { showContacts = true }
                    )
                }
                .padding(.horizontal, Theme.spacing20)
                .padding(.top, Theme.spacing24)
                .padding(.bottom, Theme.spacing48)
            }
            .navigationTitle("TidyUp")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadStorageInfo() }
            .navigationDestination(isPresented: $showSimilarPhotos) {
                if let result = viewModel.scanResult {
                    SimilarPhotosListView(groups: result.similarGroups)
                }
            }
            .navigationDestination(isPresented: $showScreenshots) {
                if let result = viewModel.scanResult {
                    ScreenshotsGridView(items: result.screenshots)
                }
            }
            .navigationDestination(isPresented: $showVideos) {
                if let result = viewModel.scanResult {
                    LargeVideosListView(items: result.videos)
                }
            }
            .navigationDestination(isPresented: $showContacts) {
                if let result = viewModel.scanResult {
                    DuplicateContactsView(groups: result.duplicateContacts)
                }
            }
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.scanState { return true }
        return false
    }
}

// MARK: - Subview Structs

private struct DashboardStorageSection: View {
    let usedBytes: Int64
    let totalBytes: Int64
    let freeableBytes: Int64

    var body: some View {
        VStack(spacing: Theme.spacing16) {
            StorageRingView(usedBytes: usedBytes, totalBytes: totalBytes)

            if freeableBytes > 0 {
                Text("Free up \(freeableBytes, format: .byteCount(style: .file))")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
            }
        }
    }
}

private struct DashboardScanControls: View {
    let scanState: DashboardViewModel.ScanState
    let onScan: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing8) {
            switch scanState {
            case .idle:
                Button("Scan Storage", systemImage: "sparkles", action: onScan)
                    .buttonStyle(.glassProminent)
                    .accessibilityHint("Scans your photos, videos, and contacts for items you can delete")

            case .scanning(let message, let progress):
                VStack(spacing: Theme.spacing8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.primary)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel", systemImage: "xmark.circle", action: onCancel)
                        .buttonStyle(.glass)
                }

            case .done:
                Button("Rescan", systemImage: "arrow.clockwise", action: onScan)
                    .buttonStyle(.glass)
            }
        }
    }
}

private struct DashboardCategoriesSection: View {
    let scanResult: ScanResult?
    let isScanning: Bool
    let onSelectSimilar: () -> Void
    let onSelectScreenshots: () -> Void
    let onSelectVideos: () -> Void
    let onSelectContacts: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Theme.spacing12) {
            VStack(spacing: Theme.spacing12) {
                CategoryRowView(
                    icon: "photo.on.rectangle.angled",
                    title: "Similar Photos",
                    color: Theme.photosColor,
                    itemCount: scanResult?.similarGroups.count ?? 0,
                    savingsBytes: scanResult?.similarGroups.reduce(0) { $0 + $1.estimatedSavings } ?? 0,
                    isScanning: isScanning,
                    action: onSelectSimilar
                )

                CategoryRowView(
                    icon: "camera.viewfinder",
                    title: "Screenshots",
                    color: Theme.screensColor,
                    itemCount: scanResult?.screenshots.count ?? 0,
                    savingsBytes: scanResult?.screenshots.reduce(0) { $0 + $1.fileSize } ?? 0,
                    isScanning: isScanning,
                    action: onSelectScreenshots
                )

                CategoryRowView(
                    icon: "video.badge.ellipsis",
                    title: "Large Videos",
                    color: Theme.videosColor,
                    itemCount: scanResult?.videos.count ?? 0,
                    savingsBytes: scanResult?.videos.reduce(0) { $0 + $1.fileSize } ?? 0,
                    isScanning: isScanning,
                    action: onSelectVideos
                )

                CategoryRowView(
                    icon: "person.2.badge.gearshape",
                    title: "Duplicate Contacts",
                    color: Theme.contactsColor,
                    itemCount: scanResult?.duplicateContacts.count ?? 0,
                    savingsBytes: 0,
                    isScanning: isScanning,
                    action: onSelectContacts
                )
            }
        }
    }
}
