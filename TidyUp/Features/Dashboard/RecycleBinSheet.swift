import SwiftUI

/// Sheet explaining iOS's 30-day "Recently Deleted" retention and offering a direct link to Apple Photos to clear it.
struct RecycleBinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing24) {
                    RecycleBinHeaderView()

                    RecycleBinExplanationCard()

                    RecycleBinStepsCard()

                    VStack(spacing: Theme.spacing12) {
                        Button {
                            if let url = URL(string: "photos-redirect://") {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: Theme.spacing8) {
                                Image(systemName: "arrow.up.right.square.fill")
                                Text("Open Photos App")
                            }
                            .font(.headline)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacing16)
                        }
                        .buttonStyle(.glassProminent)

                        Text("Scroll down to 'Recently Deleted' in the Albums tab and tap 'Delete All'.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.spacing16)
                    }
                }
                .padding(.horizontal, Theme.spacing20)
                .padding(.vertical, Theme.spacing24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recycle Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }
}

// MARK: - Subviews

private struct RecycleBinHeaderView: View {
    var body: some View {
        VStack(spacing: Theme.spacing12) {
            ZStack {
                Circle()
                    .fill(Theme.deleteRed.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "trash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.deleteRed)
            }

            VStack(spacing: Theme.spacing4) {
                Text("Recently Deleted Items")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Apple Photos holds deleted items for 30 days before permanently erasing them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing16)
            }
        }
    }
}

private struct RecycleBinExplanationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.videosColor)
                Text("Storage Not Yet Reclaimed?")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text("When TidyUp removes photos or videos, iOS moves them to Recently Deleted as a safety buffer. To immediately recover device storage, you must permanently empty that album.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

private struct RecycleBinStepsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            Text("How to Permanently Clear")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: Theme.spacing12) {
                RecycleBinStepRow(
                    stepNumber: "1",
                    title: "Open Apple Photos",
                    description: "Tap the button below to launch the system Photos app."
                )

                RecycleBinStepRow(
                    stepNumber: "2",
                    title: "Go to Recently Deleted",
                    description: "Scroll down to Utilities > Recently Deleted album."
                )

                RecycleBinStepRow(
                    stepNumber: "3",
                    title: "Tap Delete All",
                    description: "Tap Select in the top right, then Delete All to free up storage instantly."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
    }
}

private struct RecycleBinStepRow: View {
    let stepNumber: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing12) {
            Text(stepNumber)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.primary)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
