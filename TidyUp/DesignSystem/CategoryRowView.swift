import SwiftUI

/// A dashboard category card showing an icon, title, item count, and savings estimate,
/// with dynamic highlight and distinction when items are selected.
struct CategoryRowView: View {
    let icon: String
    let title: String
    let color: Color
    let itemCount: Int
    let savingsBytes: Int64
    let isScanning: Bool
    var selectedCount: Int = 0
    var selectedBytes: Int64 = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing16) {
                // Icon badge with selected checkmark distinction
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(selectedCount > 0 ? .white : color)
                        .frame(width: 44, height: 44)
                        .background(
                            selectedCount > 0 ? color : color.opacity(0.12),
                            in: .rect(cornerRadius: Theme.radiusCard)
                        )

                    if selectedCount > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white, color)
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacing4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isScanning {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if selectedCount > 0 {
                        HStack(spacing: 4) {
                            Text("\(selectedCount) of \(itemCount) selected")
                                .bold()
                            if selectedBytes > 0 {
                                Text("·")
                                Text(selectedBytes, format: .byteCount(style: .file))
                                    .bold()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
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

                // Trailing selection pill
                if selectedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                        Text("\(selectedCount)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.spacing8)
                    .padding(.vertical, Theme.spacing4)
                    .background(color, in: .capsule)
                }

                if itemCount > 0 && !isScanning {
                    if selectedCount > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(color)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, Theme.spacing12)
            .padding(.horizontal, Theme.spacing16)
            .background {
                if selectedCount > 0 {
                    color.opacity(0.08)
                        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.radiusSheet))
            .overlay {
                if selectedCount > 0 {
                    RoundedRectangle(cornerRadius: Theme.radiusSheet)
                        .stroke(color.opacity(0.75), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0 || isScanning)
        .accessibilityLabel("\(title), \(itemCount) items, \(selectedCount) selected, tap to review")
    }
}
