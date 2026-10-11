import SwiftUI
import Photos

@Observable
@MainActor
final class ReviewViewModel {
    var isDeleting = false
    var error: Error?

    private let deletionService = DeletionService()

    func performDeletion(assets: [PHAsset], contactGroups: [DuplicateContactGroup]) async {
        isDeleting = true
        error = nil

        do {
            if !assets.isEmpty {
                try await deletionService.deleteAssets(assets)
            }
            for group in contactGroups {
                try await deletionService.mergeContactGroup(group)
            }
        } catch {
            self.error = error
        }

        isDeleting = false
    }
}
