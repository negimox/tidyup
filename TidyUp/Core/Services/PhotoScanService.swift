import Photos
import Vision
import CoreImage
import SwiftData
import Foundation

/// Union-Find data structure for grouping similar photos.
private final class UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    func find(_ x: Int) -> Int {
        if parent[x] != x { parent[x] = find(parent[x]) }
        return parent[x]
    }

    func union(_ x: Int, _ y: Int) {
        let px = find(x), py = find(y)
        guard px != py else { return }
        if rank[px] < rank[py] { parent[px] = py }
        else if rank[px] > rank[py] { parent[py] = px }
        else { parent[py] = px; rank[px] += 1 }
    }
}

/// Atomic resume guard ensuring CheckedContinuation is resumed at most once.
private final class AtomicResumeBox: @unchecked Sendable {
    private var isResumed = false
    private let lock = NSLock()

    func resume(continuation: CheckedContinuation<CGImage?, Never>, with image: CGImage?) {
        lock.lock()
        defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        continuation.resume(returning: image)
    }
}

/// Performs Vision-based similar photo scanning with SwiftData caching.
actor PhotoScanService {

    // MARK: - Constants

    /// Distance threshold below which two photos are considered "similar".
    static let similarityThreshold: Float = 0.35
    /// Time window (seconds) for bucketing photos before pairwise comparison.
    static let timeBucketWindow: TimeInterval = 600 // 10 minutes
    /// Thumbnail pixel size for Vision feature print generation.
    static let thumbnailSize = 300

    // MARK: - Public Interface

    /// Scans photos and emits progress events via the returned `AsyncStream`.
    /// - Parameter modelContainer: Optional `ModelContainer` for the feature print cache.
    func scan(modelContainer: ModelContainer? = nil) -> AsyncStream<ScanProgress> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.started)
                    let groups = try await self.performScan(modelContainer: modelContainer, continuation: continuation)
                    let screenshots = try await self.fetchScreenshots()
                    continuation.yield(.scanningScreenshots)
                    let videos = try await self.fetchVideos()
                    continuation.yield(.scanningVideos)
                    let result = ScanResult(
                        similarGroups: groups,
                        screenshots: screenshots,
                        videos: videos,
                        duplicateContacts: []
                    )
                    continuation.yield(.finished(result))
                } catch is CancellationError {
                    // scan was cancelled; no event needed
                } catch {
                    continuation.yield(.failed(error))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private Implementation

    private func performScan(
        modelContainer: ModelContainer?,
        continuation: AsyncStream<ScanProgress>.Continuation
    ) async throws -> [SimilarGroup] {
        // Fetch all image assets
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let assets: [PHAsset] = (0..<result.count).map { result.object(at: $0) }

        let total = assets.count
        guard total > 0 else { return [] }

        // Preload cached feature prints on actor to avoid concurrent ModelContext access
        var cachedMap: [String: (data: Data, modDate: Date)] = [:]
        let context = modelContainer.map { ModelContext($0) }
        if let context {
            let descriptor = FetchDescriptor<CachedFeaturePrint>()
            if let cachedEntries = try? context.fetch(descriptor) {
                for entry in cachedEntries {
                    cachedMap[entry.assetLocalIdentifier] = (entry.featurePrintData, entry.assetModificationDate)
                }
            }
        }

        // Time-bucket assets
        let buckets = bucket(assets: assets)

        // Load or compute feature prints
        var featurePrints: [String: VNFeaturePrintObservation] = [:]
        var newPrintsToCache: [(id: String, data: Data, creation: Date, mod: Date)] = []
        let maxConcurrency = max(1, ProcessInfo.processInfo.activeProcessorCount)
        var processed = 0

        for bucket in buckets {
            try Task.checkCancellation()
            try await withThrowingTaskGroup(of: (String, VNFeaturePrintObservation?, (Data, Date, Date)?).self) { group in
                var pending = 0
                for asset in bucket {
                    if pending >= maxConcurrency {
                        if let (id, print, toCache) = try await group.next() {
                            if let print { featurePrints[id] = print }
                            if let (data, created, mod) = toCache {
                                newPrintsToCache.append((id, data, created, mod))
                            }
                            processed += 1
                            continuation.yield(.scanningPhotos(current: processed, total: total))
                        }
                        pending -= 1
                    }
                    let id = asset.localIdentifier
                    let cachedData = cachedMap[id]
                    group.addTask {
                        let (fp, newCache) = await self.featurePrint(
                            for: asset,
                            preloadedCache: cachedData
                        )
                        return (id, fp, newCache)
                    }
                    pending += 1
                }
                for try await (id, print, toCache) in group {
                    if let print { featurePrints[id] = print }
                    if let (data, created, mod) = toCache {
                        newPrintsToCache.append((id, data, created, mod))
                    }
                    processed += 1
                    continuation.yield(.scanningPhotos(current: processed, total: total))
                }
            }
        }

        // Batch save newly computed prints into SwiftData
        if let context, !newPrintsToCache.isEmpty {
            for item in newPrintsToCache {
                let cached = CachedFeaturePrint(
                    assetLocalIdentifier: item.id,
                    featurePrintData: item.data,
                    creationDate: item.creation,
                    assetModificationDate: item.mod
                )
                context.insert(cached)
            }
            try? context.save()
        }

        continuation.yield(.groupingPhotos)
        try Task.checkCancellation()

        // Build groups using union-find
        return buildGroups(assets: assets, featurePrints: featurePrints)
    }

    /// Splits an asset array into 10-minute time buckets.
    private func bucket(assets: [PHAsset]) -> [[PHAsset]] {
        guard !assets.isEmpty else { return [] }
        var buckets: [[PHAsset]] = []
        var current: [PHAsset] = []
        var bucketStart: Date = assets[0].creationDate ?? .distantPast

        for asset in assets {
            let date = asset.creationDate ?? .distantPast
            if date.timeIntervalSince(bucketStart) > Self.timeBucketWindow {
                if !current.isEmpty { buckets.append(current) }
                current = [asset]
                bucketStart = date
            } else {
                current.append(asset)
            }
        }
        if !current.isEmpty { buckets.append(current) }
        return buckets
    }

    /// Returns a cached or freshly computed `VNFeaturePrintObservation` for the given asset.
    private func featurePrint(
        for asset: PHAsset,
        preloadedCache: (data: Data, modDate: Date)?
    ) async -> (VNFeaturePrintObservation?, (Data, Date, Date)?) {
        let modDate = asset.modificationDate ?? asset.creationDate ?? .distantPast

        // Check preloaded in-memory cache
        if let cached = preloadedCache, cached.modDate >= modDate {
            if let observation = try? VNFeaturePrintObservation.fromData(cached.data) {
                return (observation, nil)
            }
        }

        // Request thumbnail
        guard let image = await requestThumbnail(for: asset) else { return (nil, nil) }

        // Compute feature print
        guard let fp = computeFeaturePrint(for: image) else { return (nil, nil) }

        // Prepare new cache entry
        if let data = try? fp.toData() {
            let creation = asset.creationDate ?? .distantPast
            return (fp, (data, creation, modDate))
        }

        return (fp, nil)
    }

    private func requestThumbnail(for asset: PHAsset) async -> CGImage? {
        let size = CGSize(width: Self.thumbnailSize, height: Self.thumbnailSize)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false

        let box = AtomicResumeBox()
        return await withCheckedContinuation { cont in
            _ = autoreleasepool {
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: size,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    box.resume(continuation: cont, with: image?.cgImage)
                }
            }
        }
    }

    private func computeFeaturePrint(for image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    private func buildGroups(
        assets: [PHAsset],
        featurePrints: [String: VNFeaturePrintObservation]
    ) -> [SimilarGroup] {
        let uf = UnionFind(count: assets.count)

        // Only compare within buckets to avoid O(n²) globally
        let buckets = bucket(assets: assets)
        var assetIndex: [String: Int] = [:]
        for (i, a) in assets.enumerated() { assetIndex[a.localIdentifier] = i }

        for bucket in buckets {
            for i in 0..<bucket.count {
                guard let pi = assetIndex[bucket[i].localIdentifier],
                      let fpi = featurePrints[bucket[i].localIdentifier] else { continue }
                for j in (i+1)..<bucket.count {
                    guard let pj = assetIndex[bucket[j].localIdentifier],
                          let fpj = featurePrints[bucket[j].localIdentifier] else { continue }
                    var distance: Float = 0
                    if (try? fpi.computeDistance(&distance, to: fpj)) != nil,
                       distance < Self.similarityThreshold {
                        uf.union(pi, pj)
                    }
                }
            }
        }

        // Collect roots → group
        var roots: [Int: [Int]] = [:]
        for i in 0..<assets.count {
            guard featurePrints[assets[i].localIdentifier] != nil else { continue }
            let root = uf.find(i)
            roots[root, default: []].append(i)
        }

        var groups: [SimilarGroup] = []
        for (_, indices) in roots where indices.count > 1 {
            let groupAssets = indices.map { assets[$0] }
            let best = pickBest(from: groupAssets)
            let others = groupAssets.filter { $0.localIdentifier != best.localIdentifier }
            let savings = others.reduce(Int64(0)) { sum, a in
                sum + Int64(a.pixelWidth * a.pixelHeight * 3)
            }
            groups.append(SimilarGroup(bestAsset: best, otherAssets: others, estimatedSavings: savings))
        }
        return groups.sorted { $0.estimatedSavings > $1.estimatedSavings }
    }

    /// Heuristic: higher resolution + favourite flag = better shot.
    private func pickBest(from assets: [PHAsset]) -> PHAsset {
        assets.max { a, b in
            let scoreA = a.pixelWidth * a.pixelHeight + (a.isFavorite ? 10_000_000 : 0)
            let scoreB = b.pixelWidth * b.pixelHeight + (b.isFavorite ? 10_000_000 : 0)
            return scoreA < scoreB
        } ?? assets[0]
    }

    // MARK: - Screenshots

    private func fetchScreenshots() async throws -> [ScreenshotItem] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var items: [ScreenshotItem] = []
        for i in 0..<result.count {
            let asset = result.object(at: i)
            let size = fileSize(for: asset)
            items.append(ScreenshotItem(asset: asset, fileSize: size))
        }
        return items
    }

    // MARK: - Videos

    private func fetchVideos() async throws -> [VideoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        let result = PHAsset.fetchAssets(with: .video, options: options)
        var items: [VideoItem] = []
        for i in 0..<result.count {
            let asset = result.object(at: i)
            let size = fileSize(for: asset)
            items.append(VideoItem(asset: asset, fileSize: size, duration: asset.duration))
        }
        // Sort by file size descending
        return items.sorted { $0.fileSize > $1.fileSize }
    }

    // MARK: - Helpers

    private func fileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64, size > 0 {
                return size
            }
        }
        if asset.mediaType == .video {
            return max(1_000_000, Int64(asset.duration * 2_500_000))
        }
        return Int64(asset.pixelWidth * asset.pixelHeight * 3)
    }
}

// MARK: - VNFeaturePrintObservation Serialization & Concurrency
extension VNFeaturePrintObservation: @unchecked @retroactive Sendable {}

extension VNFeaturePrintObservation {
    func toData() throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
    }

    static func fromData(_ data: Data) throws -> VNFeaturePrintObservation {
        guard let fp = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        ) else {
            throw CocoaError(.coderInvalidValue)
        }
        return fp
    }
}
