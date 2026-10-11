import SwiftUI
import Photos

/// Shared thumbnail helper that loads a PHAsset thumbnail asynchronously.
struct AssetThumbnail: View {
    let asset: PHAsset
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.12)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        let px = Int(size * 2) // Retina
        let targetSize = CGSize(width: px, height: px)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        let stream = AsyncStream<UIImage?> { continuation in
            let reqID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { img, info in
                if let img {
                    continuation.yield(img)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                if !isDegraded || isCancelled || hasError || img == nil {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                PHImageManager.default().cancelImageRequest(reqID)
            }
        }

        for await img in stream {
            guard !Task.isCancelled else { break }
            if let img {
                self.image = img
            }
        }
    }
}
