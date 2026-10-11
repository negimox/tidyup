import SwiftUI
import Photos
@preconcurrency import Contacts

/// Final review screen before deletions occur, matching Page 9 of the design reference.
struct ReviewDeleteView: View {
    let selectedPhotoIDs: Set<String>
    let allAssets: [PHAsset]
    let contactGroups: [DuplicateContactGroup]

    var onReturnToHome: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReviewViewModel()
    @State private var showSpaceFreed = false

    private var selectedAssets: [PHAsset] {
        allAssets.filter { selectedPhotoIDs.contains($0.localIdentifier) }
    }

    private var screenshotAssets: [PHAsset] {
        selectedAssets.filter { $0.mediaSubtypes.contains(.photoScreenshot) }
    }

    private var videoAssets: [PHAsset] {
        selectedAssets.filter { $0.mediaType == .video }
    }

    private var similarPhotoAssets: [PHAsset] {
        selectedAssets.filter { $0.mediaType == .image && !$0.mediaSubtypes.contains(.photoScreenshot) }
    }

    private var similarPhotosBytes: Int64 {
        similarPhotoAssets.reduce(0) { $0 + assetFileSize($1) }
    }

    private var screenshotBytes: Int64 {
        screenshotAssets.reduce(0) { $0 + assetFileSize($1) }
    }

    private var videoBytes: Int64 {
        videoAssets.reduce(0) { $0 + assetFileSize($1) }
    }

    private var totalFreedBytes: Int64 {
        similarPhotosBytes + screenshotBytes + videoBytes
    }

    private var totalItemCount: Int {
        selectedAssets.count + contactGroups.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing16) {
                ReviewHeroCard(
                    totalFreedBytes: totalFreedBytes,
                    totalItemCount: totalItemCount
                )

                if !similarPhotoAssets.isEmpty {
                    ReviewCategoryCard(
                        title: "Similar Photos",
                        subtitle: "\(similarPhotoAssets.count) photo\(similarPhotoAssets.count == 1 ? "" : "s")",
                        icon: "photo.stack.fill",
                        iconColor: Theme.photosColor,
                        freedBytesText: similarPhotosBytes.formatted(.byteCount(style: .file)),
                        assets: similarPhotoAssets
                    )
                }

                if !screenshotAssets.isEmpty {
                    ReviewCategoryCard(
                        title: "Screenshots",
                        subtitle: "\(screenshotAssets.count) item\(screenshotAssets.count == 1 ? "" : "s")",
                        icon: "camera.viewfinder",
                        iconColor: Theme.screensColor,
                        freedBytesText: screenshotBytes.formatted(.byteCount(style: .file)),
                        assets: screenshotAssets
                    )
                }

                if !videoAssets.isEmpty {
                    ReviewCategoryCard(
                        title: "Large Videos",
                        subtitle: "\(videoAssets.count) video\(videoAssets.count == 1 ? "" : "s")",
                        icon: "video.fill",
                        iconColor: Theme.videosColor,
                        freedBytesText: videoBytes.formatted(.byteCount(style: .file)),
                        assets: videoAssets
                    )
                }

                if !contactGroups.isEmpty {
                    ReviewContactCategoryCard(
                        title: "Duplicate Contacts",
                        subtitle: "\(contactGroups.count) merged",
                        icon: "person.2.fill",
                        iconColor: Theme.contactsColor,
                        freedText: "—",
                        contactGroups: contactGroups
                    )
                }

                if totalItemCount == 0 {
                    Text("No items selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacing32)
                }

                ReviewSafetyNoticeCard()
            }
            .padding(.horizontal, Theme.spacing20)
            .padding(.top, Theme.spacing16)
            .padding(.bottom, Theme.spacing24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ReviewActionButtons(
                totalItemCount: totalItemCount,
                isDeleting: viewModel.isDeleting,
                errorMessage: viewModel.error?.localizedDescription,
                onDelete: {
                    Task {
                        await viewModel.performDeletion(
                            assets: selectedAssets,
                            contactGroups: contactGroups
                        )
                        if viewModel.error == nil {
                            showSpaceFreed = true
                        }
                    }
                },
                onCancel: {
                    dismiss()
                }
            )
        }
        .navigationDestination(isPresented: $showSpaceFreed) {
            SpaceFreedView(
                itemCount: selectedAssets.count,
                contactsMerged: contactGroups.count,
                freedBytes: totalFreedBytes,
                onReturnToHome: onReturnToHome
            )
        }
    }

    private func assetFileSize(_ asset: PHAsset) -> Int64 {
        if asset.mediaType == .video {
            return max(1_000_000, Int64(asset.duration * 2_500_000))
        }
        // Approximate compressed HEIC/JPEG size without blocking main thread on assetsd IPC
        let pixels = Int64(asset.pixelWidth * asset.pixelHeight)
        if pixels > 0 {
            return max(400_000, pixels / 3)
        }
        return 2_500_000
    }
}

// MARK: - Review Hero Card

private struct ReviewHeroCard: View {
    let totalFreedBytes: Int64
    let totalItemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("You'll free up")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if totalFreedBytes > 0 {
                Text(totalFreedBytes, format: .byteCount(style: .file))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primary)
            } else if totalItemCount > 0 {
                Text("Contacts")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primary)
            } else {
                Text("0 B")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primary)
            }

            Text("\(totalItemCount) item\(totalItemCount == 1 ? "" : "s") selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

// MARK: - Review Category Card

private struct ReviewCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let freedBytesText: String
    let assets: [PHAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: icon)
                            .font(.body.bold())
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(freedBytesText)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if !assets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.spacing8) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            ReviewAssetThumbnailItem(asset: asset)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Theme.spacing16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

// MARK: - Review Asset Thumbnail Item

private struct ReviewAssetThumbnailItem: View {
    let asset: PHAsset

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssetThumbnail(asset: asset, size: 52)
                .frame(width: 52, height: 52)

            if asset.mediaType == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(.black.opacity(0.6))
                    .clipShape(.circle)
                    .padding(4)
            }
        }
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Review Contact Category Card

private struct ReviewContactCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let freedText: String
    let contactGroups: [DuplicateContactGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: icon)
                            .font(.body.bold())
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(freedText)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if !contactGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.spacing12) {
                        ForEach(contactGroups) { group in
                            ReviewContactAvatarItem(group: group)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Theme.spacing16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

// MARK: - Review Contact Avatar Item

private struct ReviewContactAvatarItem: View {
    let group: DuplicateContactGroup

    private var displayName: String {
        let name = "\(group.primary.givenName) \(group.primary.familyName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Contact" : name
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Theme.contactsColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.contactsColor)
            }
            Text(displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 56)
        }
    }
}

// MARK: - Review Safety Notice Card

private struct ReviewSafetyNoticeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            Text("Items move to Recently Deleted for 30 days.")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.bestGreen)

            Text("Nothing is removed without your confirmation.")
                .font(.subheadline)
                .foregroundStyle(Theme.bestGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing16)
        .background(Color.green.opacity(0.12))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

// MARK: - Review Action Buttons

private struct ReviewActionButtons: View {
    let totalItemCount: Int
    let isDeleting: Bool
    let errorMessage: String?
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.deleteRed)
                    .multilineTextAlignment(.center)
            }

            Button {
                onDelete()
            } label: {
                HStack(spacing: Theme.spacing8) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                        Text("Deleting…")
                    } else {
                        Text("Delete \(totalItemCount) item\(totalItemCount == 1 ? "" : "s")")
                    }
                }
                .font(.headline)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(totalItemCount > 0 ? Theme.deleteRed : Color.secondary.opacity(0.3))
                .clipShape(.rect(cornerRadius: Theme.radiusSheet))
            }
            .buttonStyle(.plain)
            .disabled(totalItemCount == 0 || isDeleting)

            Button("Cancel") {
                onCancel()
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacing8)
            .disabled(isDeleting)
        }
        .padding(.horizontal, Theme.spacing20)
        .padding(.top, Theme.spacing12)
        .padding(.bottom, Theme.spacing8)
        .background(Color(.systemGroupedBackground))
    }
}
