import Foundation

/// Progress events emitted during a scan via `AsyncStream`.
enum ScanProgress: Sendable {
    case started
    case scanningPhotos(current: Int, total: Int)
    case groupingPhotos
    case scanningScreenshots
    case scanningVideos
    case scanningContacts
    case finished(ScanResult)
    case failed(Error)
}
