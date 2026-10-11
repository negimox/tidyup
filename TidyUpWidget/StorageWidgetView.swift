import SwiftUI
import WidgetKit
import AppIntents

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetStorageData

    var usedBytes: Int64 { data.usedBytes }
    var totalBytes: Int64 { data.totalBytes }
    var freeBytes: Int64 { data.freeBytes }
    var fraction: Double { data.fraction }
    var hasScanned: Bool { data.hasScanned }
    var freeableBytes: Int64 { data.freeableBytes }

    var breakdownSummary: String {
        if data.freeableBytes <= 0 {
            return "No items to clear"
        }
        var parts: [String] = []
        if data.screenshotsBytes > 0 {
            parts.append("Screenshots")
        }
        if data.videosBytes > 0 {
            parts.append("Videos")
        }
        if data.similarPhotosBytes > 0 {
            parts.append("Similar photos")
        }
        if data.contactDuplicatesCount > 0 {
            parts.append("Duplicates")
        }
        if parts.isEmpty {
            return "Photos & media ready to reclaim"
        }
        return parts.joined(separator: " · ")
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

// MARK: - Small Widget Views

struct SmallStorageWidgetView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        Group {
            if entry.hasScanned {
                SmallStorageScannedView(entry: entry)
            } else {
                SmallStorageIdleView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color(.secondarySystemBackground)
        }
    }
}

struct SmallStorageIdleView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.indigo)
                Text("Storage")
                    .font(.caption)
                    .bold()
                Spacer()
                Text(entry.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.usedBytes, format: .byteCount(style: .file))
                .font(.headline)
                .bold()
                .contentTransition(.numericText())

            Text("of \(entry.totalBytes, format: .byteCount(style: .file)) used")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ProgressView(value: entry.fraction)
                .tint(Color.indigo)

            Spacer()

            Button(intent: ScanStorageIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold())
                    Text("Scan Now")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .widgetURL(URL(string: "tidyup://dashboard"))
    }
}

struct SmallStorageScannedView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.green)
                Text("Cleanable")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Color.green)
                Spacer()
                Button(intent: ScanStorageIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(entry.freeableBytes, format: .byteCount(style: .file))
                .font(.title2)
                .bold()
                .foregroundStyle(Color.green)
                .contentTransition(.numericText())

            Text("can be freed up")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Text("Clean in App")
                    .font(.caption.bold())
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.18))
            .foregroundStyle(Color.green)
            .clipShape(.capsule)
        }
        .widgetURL(URL(string: "tidyup://dashboard?scan_ready=true"))
    }
}

// MARK: - Medium Widget Views

struct MediumStorageWidgetView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            WidgetMiniGaugeView(entry: entry)

            Divider()

            Group {
                if entry.hasScanned {
                    MediumStorageScannedDetailsView(entry: entry)
                } else {
                    MediumStorageIdleDetailsView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .containerBackground(for: .widget) {
            Color(.secondarySystemBackground)
        }
        .widgetURL(URL(string: entry.hasScanned ? "tidyup://dashboard?scan_ready=true" : "tidyup://dashboard"))
    }
}

struct WidgetMiniGaugeView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: entry.fraction)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(entry.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline)
                    .bold()
            }
            .frame(width: 66, height: 66)

            VStack(spacing: 1) {
                Text(entry.usedBytes, format: .byteCount(style: .file))
                    .font(.caption2)
                    .bold()
                Text("of \(entry.totalBytes, format: .byteCount(style: .file))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 84)
    }
}

struct MediumStorageIdleDetailsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TidyUp Storage")
                    .font(.headline)
                    .bold()
                Spacer()
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.indigo)
            }

            Text("Find duplicate photos, large videos and screenshots.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            Button(intent: ScanStorageIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.bold())
                    Text("Scan Now")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

struct MediumStorageScannedDetailsView: View {
    let entry: StorageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold())
                    Text("Space to be Cleared")
                        .font(.caption)
                        .bold()
                }
                .foregroundStyle(Color.green)

                Spacer()

                Button(intent: ScanStorageIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(entry.freeableBytes, format: .byteCount(style: .file))
                .font(.title2)
                .bold()
                .foregroundStyle(Color.green)
                .contentTransition(.numericText())

            Text(entry.breakdownSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Link(destination: URL(string: "tidyup://dashboard?scan_ready=true")!) {
                HStack(spacing: 6) {
                    Text("Clean in TidyUp")
                        .font(.subheadline.bold())
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }
}
