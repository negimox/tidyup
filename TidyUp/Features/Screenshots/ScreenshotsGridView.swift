import SwiftUI
import Photos

struct ScreenshotsGridView: View {
    let items: [ScreenshotItem]
    var onReturnToHome: (() -> Void)? = nil
    @State private var selected: Set<String> = []
    @State private var showReview = false
    @State private var previewItem: PhotoPreviewItem? = nil

    private var selectedBytes: Int64 {
        items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Screenshots",
                    systemImage: "camera.viewfinder",
                    description: Text("No screenshots found in your library.")
                )
            } else {
                ScrollView {
                    VStack(spacing: Theme.spacing12) {
                        ScreenshotHeaderToolbar(
                            count: items.count,
                            allSelected: allSelected,
                            onToggleAll: {
                                if allSelected {
                                    selected.removeAll()
                                } else {
                                    selected = Set(items.map { $0.id })
                                }
                            }
                        )
                        .padding(.horizontal, Theme.spacing4)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.spacing8)],
                            spacing: Theme.spacing8
                        ) {
                            ForEach(items) { item in
                                ScreenshotCell(
                                    item: item,
                                    isSelected: selected.contains(item.id),
                                    action: {
                                        toggleSelection(item.id)
                                    },
                                    onView: {
                                        previewItem = PhotoPreviewItem(asset: item.asset, isBest: false)
                                    }
                                )
                            }
                        }
                    }
                    .padding(Theme.spacing16)
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
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewItem) { item in
            PhotoPreviewSheet(
                asset: item.asset,
                isBest: false,
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
                allAssets: items.map { $0.asset },
                contactGroups: [],
                onReturnToHome: onReturnToHome
            )
        }
    }

    private var allSelected: Bool { selected.count == items.count }

    private func toggleSelection(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}

// MARK: - Header Toolbar

private struct ScreenshotHeaderToolbar: View {
    let count: Int
    let allSelected: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack {
            Text("\(count) screenshots")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                .font(.subheadline)
        }
    }
}

// MARK: - Cell

private struct ScreenshotCell: View {
    let item: ScreenshotItem
    let isSelected: Bool
    let action: () -> Void
    let onView: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                AssetThumbnail(asset: item.asset, size: 110)
                    .frame(width: 110, height: 110)
                    .clipShape(.rect(cornerRadius: Theme.radiusCard))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusCard)
                            .stroke(isSelected ? Theme.deleteRed : .clear, lineWidth: 2)
                    }
                    .opacity(isSelected ? 0.75 : 1)
            }
            .buttonStyle(.plain)

            Button(action: action) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? Theme.deleteRed : .white)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white : Color.black.opacity(0.35))
                            .frame(width: 16, height: 16)
                    )
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
                    .accessibilityLabel("View screenshot in full screen")
                    Spacer()
                }
            }
            .padding(6)
        }
        .frame(width: 110, height: 110)
        .accessibilityLabel("Screenshot, \(isSelected ? "selected" : "not selected")")
    }
}
