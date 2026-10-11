import Foundation

/// Combined output of a full scan.
struct ScanResult: Sendable {
    var similarGroups: [SimilarGroup] = []
    var screenshots: [ScreenshotItem] = []
    var videos: [VideoItem] = []
    var duplicateContacts: [DuplicateContactGroup] = []

    /// Total bytes that could be freed by acting on all scan results.
    var totalFreeable: Int64 {
        let photoBytes = similarGroups.reduce(0) { $0 + $1.estimatedSavings }
        let screenshotBytes = screenshots.reduce(0) { $0 + $1.fileSize }
        let videoBytes = videos.reduce(0) { $0 + $1.fileSize }
        return photoBytes + screenshotBytes + videoBytes
    }
}
