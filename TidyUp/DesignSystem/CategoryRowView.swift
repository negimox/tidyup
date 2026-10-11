import SwiftUI

/// A dashboard category card showing an icon, title, item count, and savings estimate.
struct CategoryRowView: View {
    let icon: String
    let title: String
    let color: Color
    let itemCount: Int
    let savingsBytes: Int64
    let isScanning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing16) {
                // Icon badge
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusCard))

                VStack(alignment: .leading, spacing: Theme.spacing4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isScanning {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if itemCount > 0 {
                        Text("\(itemCount) items · \(savingsBytes, format: .byteCount(style: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } else {
                        Text("No duplicates found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if itemCount > 0 && !isScanning {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, Theme.spacing12)
            .padding(.horizontal, Theme.spacing16)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: Theme.radiusCard))
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0 || isScanning)
        .accessibilityLabel("\(title), \(itemCount) items, tap to review")
    }
}
