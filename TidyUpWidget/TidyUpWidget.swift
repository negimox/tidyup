import WidgetKit
import SwiftUI

struct StorageTimelineProvider: TimelineProvider {
    typealias Entry = StorageWidgetEntry

    func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let current = WidgetDataStore.shared.load()
        let displayData = current.hasScanned ? current : .previewScanned
        completion(StorageWidgetEntry(date: Date(), data: displayData))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let current = WidgetDataStore.shared.load()
        let entry = StorageWidgetEntry(date: Date(), data: current)
        // Refresh every 30 minutes or on explicit reload via WidgetCenter
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TidyUpStorageWidget: Widget {
    let kind: String = "TidyUpStorageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StorageTimelineProvider()) { entry in
            StorageWidgetView(entry: entry)
        }
        .configurationDisplayName("Storage & Cleaner")
        .description("Track storage and scan for cleanable duplicate photos, videos, and screenshots.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TidyUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        TidyUpStorageWidget()
    }
}

// MARK: - Previews

#Preview("Small - Idle", as: .systemSmall) {
    TidyUpStorageWidget()
} timeline: {
    StorageWidgetEntry(date: Date(), data: .placeholder)
}

#Preview("Small - Scanned", as: .systemSmall) {
    TidyUpStorageWidget()
} timeline: {
    StorageWidgetEntry(date: Date(), data: .previewScanned)
}

#Preview("Medium - Idle", as: .systemMedium) {
    TidyUpStorageWidget()
} timeline: {
    StorageWidgetEntry(date: Date(), data: .placeholder)
}

#Preview("Medium - Scanned", as: .systemMedium) {
    TidyUpStorageWidget()
} timeline: {
    StorageWidgetEntry(date: Date(), data: .previewScanned)
}
