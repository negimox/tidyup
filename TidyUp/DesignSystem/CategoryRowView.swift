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
    var unit: String = "items"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing16) {
                // Icon badge with selected checkmark distinction
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(color, in: .rect(cornerRadius: 12))

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
                        .bold()
                        .foregroundStyle(.primary)

                    if isScanning {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if selectedCount > 0 {
                        Text("\(selectedCount) of \(itemCount) selected")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(color)
                            .contentTransition(.numericText())
                    } else if itemCount > 0 {
                        Text("\(itemCount) \(unit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    } else {
                        Text("None found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Trailing savings or selection pill + chevron
                HStack(spacing: Theme.spacing8) {
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
                    } else if !isScanning {
                        if savingsBytes > 0 {
                            Text(savingsBytes, format: .byteCount(style: .file))
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.primary)
                        } else {
                            Text("—")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                    }

                    if itemCount > 0 && !isScanning {
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(selectedCount > 0 ? color : Color.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, Theme.spacing12)
            .padding(.horizontal, Theme.spacing16)
            .background {
                if selectedCount > 0 {
                    color.opacity(0.08)
                        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
                } else {
                    Color(.secondarySystemGroupedBackground)
                        .clipShape(.rect(cornerRadius: Theme.radiusSheet))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusSheet)
                    .stroke(selectedCount > 0 ? color.opacity(0.75) : Color.primary.opacity(0.04), lineWidth: selectedCount > 0 ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0 || isScanning)
        .accessibilityLabel("\(title), \(itemCount) \(unit), \(selectedCount) selected, tap to review")
    }
}
