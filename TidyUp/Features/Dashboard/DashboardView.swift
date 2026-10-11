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
                    storageSection
                    scanButton
                    categoriesSection
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

    // MARK: - Subviews

    private var storageSection: some View {
        VStack(spacing: Theme.spacing16) {
            StorageRingView(usedBytes: viewModel.usedBytes, totalBytes: viewModel.totalBytes)

            if let result = viewModel.scanResult, result.totalFreeable > 0 {
                Text("Free up \(result.totalFreeable, format: .byteCount(style: .file))")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
            }
        }
    }

    private var scanButton: some View {
        VStack(spacing: Theme.spacing8) {
            switch viewModel.scanState {
            case .idle:
                Button("Scan Storage", systemImage: "sparkles") {
                    viewModel.startScan(context: modelContext)
                }
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
                    Button("Cancel", systemImage: "xmark.circle") {
                        viewModel.cancelScan()
                    }
                    .buttonStyle(.glass)
                }

            case .done:
                Button("Rescan", systemImage: "arrow.clockwise") {
                    viewModel.startScan(context: modelContext)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var categoriesSection: some View {
        VStack(spacing: Theme.spacing12) {
            CategoryRowView(
                icon: "photo.on.rectangle.angled",
                title: "Similar Photos",
                color: Theme.photosColor,
                itemCount: viewModel.scanResult?.similarGroups.count ?? 0,
                savingsBytes: viewModel.scanResult?.similarGroups.reduce(0) { $0 + $1.estimatedSavings } ?? 0,
                isScanning: isScanning,
                action: { showSimilarPhotos = true }
            )

            CategoryRowView(
                icon: "camera.viewfinder",
                title: "Screenshots",
                color: Theme.screensColor,
                itemCount: viewModel.scanResult?.screenshots.count ?? 0,
                savingsBytes: viewModel.scanResult?.screenshots.reduce(0) { $0 + $1.fileSize } ?? 0,
                isScanning: isScanning,
                action: { showScreenshots = true }
            )

            CategoryRowView(
                icon: "video.badge.ellipsis",
                title: "Large Videos",
                color: Theme.videosColor,
                itemCount: viewModel.scanResult?.videos.count ?? 0,
                savingsBytes: viewModel.scanResult?.videos.reduce(0) { $0 + $1.fileSize } ?? 0,
                isScanning: isScanning,
                action: { showVideos = true }
            )

            CategoryRowView(
                icon: "person.2.badge.gearshape",
                title: "Duplicate Contacts",
                color: Theme.contactsColor,
                itemCount: viewModel.scanResult?.duplicateContacts.count ?? 0,
                savingsBytes: 0,
                isScanning: isScanning,
                action: { showContacts = true }
            )
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.scanState { return true }
        return false
    }
}
