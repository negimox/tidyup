import SwiftUI

/// Animated circular storage ring showing storage usage percentage,
/// matching Figma Page 3 design.
struct StorageRingView: View {
    let usedBytes: Int64
    let totalBytes: Int64

    private var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(totalBytes)))
    }

    private var percentage: Int {
        guard totalBytes > 0 else { return 0 }
        return Int(round(fraction * 100))
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Theme.primary.opacity(0.14), lineWidth: 14)

            // Progress arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Theme.primary,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: fraction)

            // Center percentage label matching Figma
            Text("\(percentage)%")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percentage)% of storage used")
    }
}
