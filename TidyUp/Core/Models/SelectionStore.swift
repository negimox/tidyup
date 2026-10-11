import SwiftUI
import Photos
@preconcurrency import Contacts

/// Centralized observable selection store that persists selections across all 4 cleanup views and the Dashboard.
@Observable
@MainActor
final class SelectionStore {
    // 1. Similar Photos
    var selectedSimilarPhotoIDs: Set<String> = []

    // 2. Screenshots
    var selectedScreenshotIDs: Set<String> = []

    // 3. Large Videos
    var selectedVideoIDs: Set<String> = []

    // 4. Duplicate Contacts
    var selectedContactGroupIDs: Set<UUID> = []

    // MARK: - Counts

    var similarPhotosCount: Int {
        selectedSimilarPhotoIDs.count
    }

    var screenshotsCount: Int {
        selectedScreenshotIDs.count
    }

    var videosCount: Int {
        selectedVideoIDs.count
    }

    var contactsCount: Int {
        selectedContactGroupIDs.count
    }

    var totalSelectedCount: Int {
        similarPhotosCount + screenshotsCount + videosCount + contactsCount
    }

    var hasSelections: Bool {
        totalSelectedCount > 0
    }

    // MARK: - Combined Assets for Review

    var allSelectedPhotoIDs: Set<String> {
        selectedSimilarPhotoIDs.union(selectedScreenshotIDs).union(selectedVideoIDs)
    }

    // MARK: - Byte Calculations

    func similarPhotosBytes(from scanResult: ScanResult?) -> Int64 {
        guard let scanResult else { return 0 }
        let allAssets = scanResult.similarGroups.flatMap { [$0.bestAsset] + $0.otherAssets }
        return allAssets
            .filter { selectedSimilarPhotoIDs.contains($0.localIdentifier) }
            .reduce(0) { $0 + Int64($1.pixelWidth * $1.pixelHeight * 3) }
    }

    func screenshotsBytes(from scanResult: ScanResult?) -> Int64 {
        guard let scanResult else { return 0 }
        return scanResult.screenshots
            .filter { selectedScreenshotIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }

    func videosBytes(from scanResult: ScanResult?) -> Int64 {
        guard let scanResult else { return 0 }
        return scanResult.videos
            .filter { selectedVideoIDs.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }

    func totalSelectedBytes(from scanResult: ScanResult?) -> Int64 {
        similarPhotosBytes(from: scanResult) +
        screenshotsBytes(from: scanResult) +
        videosBytes(from: scanResult)
    }

    // MARK: - Mutations

    func toggleSimilarPhoto(_ id: String) {
        if selectedSimilarPhotoIDs.contains(id) {
            selectedSimilarPhotoIDs.remove(id)
        } else {
            selectedSimilarPhotoIDs.insert(id)
        }
    }

    func toggleScreenshot(_ id: String) {
        if selectedScreenshotIDs.contains(id) {
            selectedScreenshotIDs.remove(id)
        } else {
            selectedScreenshotIDs.insert(id)
        }
    }

    func toggleVideo(_ id: String) {
        if selectedVideoIDs.contains(id) {
            selectedVideoIDs.remove(id)
        } else {
            selectedVideoIDs.insert(id)
        }
    }

    func toggleContactGroup(_ id: UUID) {
        if selectedContactGroupIDs.contains(id) {
            selectedContactGroupIDs.remove(id)
        } else {
            selectedContactGroupIDs.insert(id)
        }
    }

    // MARK: - Clear / Reset

    func clearSimilarPhotos() {
        selectedSimilarPhotoIDs.removeAll()
    }

    func clearScreenshots() {
        selectedScreenshotIDs.removeAll()
    }

    func clearVideos() {
        selectedVideoIDs.removeAll()
    }

    func clearContacts() {
        selectedContactGroupIDs.removeAll()
    }

    func clearAll() {
        selectedSimilarPhotoIDs.removeAll()
        selectedScreenshotIDs.removeAll()
        selectedVideoIDs.removeAll()
        selectedContactGroupIDs.removeAll()
    }
}
