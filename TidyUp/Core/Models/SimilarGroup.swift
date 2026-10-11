import Photos
import Foundation

/// A group of visually similar photos, with the "best" shot identified.
struct SimilarGroup: Identifiable, Sendable {
    let id: UUID
    /// The recommended photo to keep.
    var bestAsset: PHAsset
    /// All other assets in the group (pre-selected for deletion).
    var otherAssets: [PHAsset]
    /// Estimated bytes saved by deleting `otherAssets`.
    var estimatedSavings: Int64

    init(id: UUID = UUID(), bestAsset: PHAsset, otherAssets: [PHAsset], estimatedSavings: Int64) {
        self.id = id
        self.bestAsset = bestAsset
        self.otherAssets = otherAssets
        self.estimatedSavings = estimatedSavings
    }
}
