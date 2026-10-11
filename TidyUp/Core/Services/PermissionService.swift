import Photos
@preconcurrency import Contacts

/// Handles all permission requests for Photos and Contacts.
actor PermissionService {

    // MARK: - Photos

    /// Current Photos authorization status.
    var photosStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests full read/write access to the photo library.
    /// - Returns: The resulting authorization status.
    func requestPhotosAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: - Contacts

    /// Current Contacts authorization status.
    var contactsStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Requests access to contacts.
    /// - Returns: `true` if granted, `false` otherwise.
    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }
}
