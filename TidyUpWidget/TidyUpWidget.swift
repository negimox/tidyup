import WidgetKit
import SwiftUI

struct StorageTimelineProvider: TimelineProvider {
    typealias Entry = StorageWidgetEntry

    func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(date: Date(), usedBytes: 64_000_000_000, totalBytes: 128_000_000_000)
    }

    func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let entry = currentStorageEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let entry = currentStorageEntry()
        // Reload every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentStorageEntry() -> StorageWidgetEntry {
        do {
            let url = URL.homeDirectory
            let values = try url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            let used = total - available
            return StorageWidgetEntry(date: Date(), usedBytes: max(0, used), totalBytes: max(1, total))
        } catch {
            return StorageWidgetEntry(date: Date(), usedBytes: 64_000_000_000, totalBytes: 128_000_000_000)
        }
    }
}

struct TidyUpStorageWidget: Widget {
    let kind: String = "TidyUpStorageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StorageTimelineProvider()) { entry in
            StorageWidgetView(entry: entry)
        }
        .configurationDisplayName("Device Storage")
        .description("Keep track of used and free storage on your iPhone.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TidyUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        TidyUpStorageWidget()
    }
}
