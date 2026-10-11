import AVFoundation
import Photos
import Foundation

/// Compresses large videos using AVAssetExportSession to reclaim storage.
actor VideoCompressionService {

    enum CompressionError: LocalizedError {
        case assetNotConvertible
        case exportFailed(Error?)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .assetNotConvertible:
                return "The video cannot be compressed to this preset."
            case .exportFailed(let error):
                return "Video export failed: \(error?.localizedDescription ?? "unknown error")."
            case .cancelled:
                return "Video export was cancelled."
            }
        }
    }

    /// Compresses a video PHAsset to 720p or 540p and saves it to the photo library.
    /// - Parameters:
    ///   - asset: The video PHAsset to compress.
    ///   - preset: The export preset (default: .preset1280x720).
    /// - Returns: The newly created asset's local identifier and compressed size.
    func compress(
        asset: PHAsset,
        preset: String = AVAssetExportPreset1280x720
    ) async throws -> (compressedSize: Int64, newAssetIdentifier: String) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let avAsset: AVAsset = try await withCheckedThrowingContinuation { cont in
            var resumed = false
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, info in
                guard !resumed else { return }
                resumed = true
                if let asset {
                    cont.resume(returning: asset)
                } else {
                    let error = info?[PHImageErrorKey] as? Error ?? CompressionError.assetNotConvertible
                    cont.resume(throwing: error)
                }
            }
        }

        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset) else {
            throw CompressionError.assetNotConvertible
        }

        let tempURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        exportSession.shouldOptimizeForNetworkUse = true

        do {
            try await exportSession.export(to: tempURL, as: .mp4)

            let values = try tempURL.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(values.fileSize ?? 0)

            // Save compressed video to Photos library
            var newId: String = ""
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                newId = request?.placeholderForCreatedAsset?.localIdentifier ?? ""
            }

            try? FileManager.default.removeItem(at: tempURL)
            return (size, newId)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw CompressionError.exportFailed(error)
        }
    }
}

extension AVAsset: @unchecked @retroactive Sendable {}
