import Foundation

/// Queries device storage capacity.
actor StorageService {

    /// Returns `(usedBytes, totalBytes)` for the main volume.
    func fetchCapacity() async throws -> (used: Int64, total: Int64) {
        let url = URL.homeDirectory
        let values = try url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let used = total - available
        return (used, total)
    }
}
