import Photos
import Foundation

/// A video asset with cached size and duration metadata.
struct VideoItem: Identifiable, Sendable {
    var id: String { asset.localIdentifier }
    let asset: PHAsset
    let fileSize: Int64
    let duration: TimeInterval
}
