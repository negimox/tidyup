import SwiftUI
import Photos
import SwiftData

/// Drives the main dashboard: storage stats + scan lifecycle.
@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - Storage

    var usedBytes: Int64 = 0
    var totalBytes: Int64 = 0

    // MARK: - Scan State

    enum ScanState: Equatable {
        case idle
        case scanning(message: String, progress: Double)
        case done
    }

    var scanState: ScanState = .idle
    var scanResult: ScanResult?
    var scanError: Error?

    // MARK: - Services

    private let storageService = StorageService()
    private let photoScanService = PhotoScanService()
    private let contactScanService = ContactScanService()
    private var scanTask: Task<Void, Never>?

    // MARK: - Public

    func loadStorageInfo() async {
        do {
            let (used, total) = try await storageService.fetchCapacity()
            usedBytes = used
            totalBytes = total
        } catch {
            // Non-critical; leave values at 0
        }
    }

    func startScan(modelContainer: ModelContainer? = nil) {
        if case .scanning = scanState { return }
        scanTask?.cancel()
        scanTask = Task {
            await performScan(modelContainer: modelContainer)
        }
    }

    func startScan(context: ModelContext) {
        startScan(modelContainer: context.container)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        scanState = .idle
    }

    // MARK: - Private

    private func performScan(modelContainer: ModelContainer? = nil) async {
        scanState = .scanning(message: "Starting…", progress: 0)
        scanError = nil

        let stream = await photoScanService.scan(modelContainer: modelContainer)
        for await event in stream {
            guard !Task.isCancelled else { break }
            switch event {
            case .started:
                scanState = .scanning(message: "Preparing…", progress: 0)
            case .scanningPhotos(let current, let total):
                let pct = total > 0 ? Double(current) / Double(total) : 0
                scanState = .scanning(
                    message: "Analysing photos (\(current)/\(total))",
                    progress: pct * 0.7
                )
            case .groupingPhotos:
                scanState = .scanning(message: "Grouping similar photos…", progress: 0.72)
            case .scanningScreenshots:
                scanState = .scanning(message: "Finding screenshots…", progress: 0.80)
            case .scanningVideos:
                scanState = .scanning(message: "Finding large videos…", progress: 0.88)
            case .scanningContacts:
                scanState = .scanning(message: "Scanning contacts…", progress: 0.94)
            case .finished(var result):
                // Append contacts separately
                if let groups = try? await contactScanService.scanDuplicates() {
                    result.duplicateContacts = groups
                }
                scanResult = result
                scanState = .done
                // Refresh storage after scan
                await loadStorageInfo()
            case .failed(let error):
                scanError = error
                scanState = .idle
            }
        }
    }
}
