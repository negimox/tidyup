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
                Color(.systemFill)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: asset.localIdentifier) {
            image = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        let px = Int(size * 2) // Retina
        let targetSize = CGSize(width: px, height: px)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}
