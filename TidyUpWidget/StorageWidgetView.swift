import SwiftUI
import WidgetKit

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let usedBytes: Int64
    let totalBytes: Int64

    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(usedBytes) / Double(totalBytes))
    }
}

struct StorageWidgetView: View {
    let entry: StorageWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallStorageWidgetView(entry: entry)
        case .systemMedium:
            MediumStorageWidgetView(entry: entry)
        default:
            SmallStorageWidgetView(entry: entry)
        }
    }
}

// MARK: - Subviews

private struct SmallStorageWidgetView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.indigo)
                Spacer()
                Text("\(Int(entry.fraction * 100))%")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.usedBytes, format: .byteCount(style: .file))
                .font(.title3)
                .bold()

            Text("of \(entry.totalBytes, format: .byteCount(style: .file)) used")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ProgressView(value: entry.fraction)
                .tint(Color.indigo)
        }
        .containerBackground(for: .widget) {
            Color(.secondarySystemBackground)
        }
    }
}

private struct MediumStorageWidgetView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Mini Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: entry.fraction)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(entry.fraction * 100))%")
                    .font(.subheadline)
                    .bold()
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("TidyUp Storage")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.indigo)
                }

                Text("\(entry.usedBytes, format: .byteCount(style: .file)) used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\((entry.totalBytes - entry.usedBytes), format: .byteCount(style: .file)) available")
                    .font(.caption)
                    .foregroundStyle(Color.green)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.secondarySystemBackground)
        }
    }
}
