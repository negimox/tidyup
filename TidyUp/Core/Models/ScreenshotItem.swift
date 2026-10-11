import Photos
import Foundation

/// A screenshot asset wrapper with cached file size.
struct ScreenshotItem: Identifiable, Sendable {
    /// Uses `PHAsset.localIdentifier` as stable ID.
    var id: String { asset.localIdentifier }
    let asset: PHAsset
    let fileSize: Int64
}
