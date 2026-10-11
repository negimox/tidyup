import Photos
import Foundation

/// A screenshot asset wrapper with cached file size.
struct ScreenshotItem: Identifiable, Sendable, Hashable {
    /// Uses `PHAsset.localIdentifier` as stable ID.
    var id: String { asset.localIdentifier }
    let asset: PHAsset
    let fileSize: Int64

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
