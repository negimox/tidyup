import SwiftUI

/// Animated circular storage ring shown on the dashboard.
struct StorageRingView: View {
    let usedBytes: Int64
    let totalBytes: Int64

    private var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }

    private var usedText: String {
        ByteCountFormatStyle().format(usedBytes)
    }

    private var totalText: String {
        ByteCountFormatStyle().format(totalBytes)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color(.systemFill), lineWidth: Theme.ringStroke)

            // Progress arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Theme.primary,
                    style: StrokeStyle(lineWidth: Theme.ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: fraction)

            // Center label
            VStack(spacing: Theme.spacing4) {
                Text(usedText)
                    .font(.title2)
                    .bold()
                    .contentTransition(.numericText())
                Text("of \(totalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("used")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: Theme.ringSize, height: Theme.ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(usedText) used out of \(totalText), \(Int(fraction * 100))% full"
        )
    }
}

// MARK: - ByteCountFormatStyle helper

private struct ByteCountFormatStyle {
    func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
