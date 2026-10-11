import Photos
@preconcurrency import Contacts
import Foundation

/// Handles all item deletions: photos/videos via PhotoKit, contacts via CNSaveRequest.
actor DeletionService {

    // MARK: - Photos & Videos

    /// Deletes an array of photo/video assets.
    /// The system will show its own confirmation dialog.
    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    // MARK: - Contacts

    /// Merges a duplicate contact group: unions all phone/email data into the primary
    /// contact and deletes the duplicates.
    func mergeContactGroup(_ group: DuplicateContactGroup) async throws {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()

        guard let mutablePrimary = group.primary.mutableCopy() as? CNMutableContact else { return }

        // Union phone numbers
        var allPhones = Set(mutablePrimary.phoneNumbers.map { $0.value.stringValue })
        var phones = mutablePrimary.phoneNumbers
        for dup in group.duplicates {
            for phone in dup.phoneNumbers where !allPhones.contains(phone.value.stringValue) {
                phones.append(phone)
                allPhones.insert(phone.value.stringValue)
            }
        }
        mutablePrimary.phoneNumbers = phones

        // Union emails
        var allEmails = Set(mutablePrimary.emailAddresses.map { $0.value as String })
        var emails = mutablePrimary.emailAddresses
        for dup in group.duplicates {
            for email in dup.emailAddresses where !allEmails.contains(email.value as String) {
                emails.append(email)
                allEmails.insert(email.value as String)
            }
        }
        mutablePrimary.emailAddresses = emails

        saveRequest.update(mutablePrimary)

        // Delete duplicates
        let keysToFetch = [CNContactIdentifierKey] as [CNKeyDescriptor]
        for dup in group.duplicates {
            if let mutableDup = try? store.unifiedContact(
                withIdentifier: dup.identifier,
                keysToFetch: keysToFetch
            ).mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutableDup)
            }
        }

        try store.execute(saveRequest)
    }
}
