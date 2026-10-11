import AppIntents
import WidgetKit

/// An interactive AppIntent triggered by the widget's "Scan Now" button.
/// Runs in the background, calculates possible space to be cleared, updates the shared store,
/// and reloads the widget timeline.
public struct ScanStorageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Scan Storage"
    public static let description = IntentDescription("Scans on-device storage to estimate space that can be reclaimed.")
    public static let isDiscoverable: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        _ = await WidgetDataStore.shared.performQuickScan()
        WidgetCenter.shared.reloadTimelines(ofKind: "TidyUpStorageWidget")
        return .result()
    }
}
