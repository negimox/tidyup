import SwiftData
import Foundation

/// Cached Vision feature print for a photo asset.
/// Stored in SwiftData to accelerate rescans.
@Model
final class CachedFeaturePrint {
    var assetLocalIdentifier: String = ""
    var featurePrintData: Data = Data()
    var creationDate: Date = Date.distantPast
    var assetModificationDate: Date = Date.distantPast

    init(
        assetLocalIdentifier: String,
        featurePrintData: Data,
        creationDate: Date,
        assetModificationDate: Date
    ) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.featurePrintData = featurePrintData
        self.creationDate = creationDate
        self.assetModificationDate = assetModificationDate
    }
}
