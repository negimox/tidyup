import Photos
import Foundation

/// A video asset with cached size and duration metadata.
struct VideoItem: Identifiable, Sendable, Hashable {
    var id: String { asset.localIdentifier }
    let asset: PHAsset
    let fileSize: Int64
    let duration: TimeInterval

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
