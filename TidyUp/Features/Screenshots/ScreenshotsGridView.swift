import SwiftUI
import Photos

struct ScreenshotsGridView: View {
    let items: [ScreenshotItem]
    var onReturnToHome: (() -> Void)? = nil
    @State private var selected: Set<String> = []
    @State private var showReview = false

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
                .padding(.horizontal, Theme.spacing20)
                .padding(.vertical, Theme.spacing12)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.spacing8)],
                        spacing: Theme.spacing8
                    ) {
                        ForEach(items) { item in
                            ScreenshotCell(
                                item: item,
                                isSelected: selected.contains(item.id)
                            ) {
                                toggleSelection(item.id)
                            }
                        }
                    }
                    .padding(Theme.spacing16)
                }
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
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.large)
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

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                AssetThumbnail(asset: item.asset, size: 110)
                    .clipShape(.rect(cornerRadius: Theme.radiusCard))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusCard)
                            .stroke(isSelected ? Theme.deleteRed : .clear, lineWidth: 3)
                    }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.deleteRed : .white)
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Screenshot, \(isSelected ? "selected" : "not selected")")
    }
}
