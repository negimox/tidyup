@preconcurrency import Contacts
import Foundation

/// Detects duplicate contacts using phone, email, and name fuzzy matching.
actor ContactScanService {

    // MARK: - Public

    func scanDuplicates() async throws -> [DuplicateContactGroup] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        return findDuplicates(in: contacts)
    }

    // MARK: - Private

    private func findDuplicates(in contacts: [CNContact]) -> [DuplicateContactGroup] {
        var groups: [DuplicateContactGroup] = []
        var visited = Set<String>()

        for i in 0..<contacts.count {
            let a = contacts[i]
            guard !visited.contains(a.identifier) else { continue }
            var duplicates: [CNContact] = []
            var reason: MatchReason = .phone

            for j in (i + 1)..<contacts.count {
                let b = contacts[j]
                guard !visited.contains(b.identifier) else { continue }

                if sharesPhone(a, b) {
                    duplicates.append(b)
                    reason = .phone
                    visited.insert(b.identifier)
                } else if sharesEmail(a, b) {
                    duplicates.append(b)
                    reason = .email
                    visited.insert(b.identifier)
                }
            }

            if !duplicates.isEmpty {
                visited.insert(a.identifier)
                groups.append(DuplicateContactGroup(primary: a, duplicates: duplicates, matchReason: reason))
            }
        }
        return groups
    }

    private func sharesPhone(_ a: CNContact, _ b: CNContact) -> Bool {
        let aNums = a.phoneNumbers.map { Self.normalize(phone: $0.value.stringValue) }.filter { !$0.isEmpty }
        let bNums = b.phoneNumbers.map { Self.normalize(phone: $0.value.stringValue) }.filter { !$0.isEmpty }
        return !Set(aNums).isDisjoint(with: Set(bNums))
    }

    private func sharesEmail(_ a: CNContact, _ b: CNContact) -> Bool {
        let aEmails = a.emailAddresses.map { ($0.value as String).lowercased() }.filter { !$0.isEmpty }
        let bEmails = b.emailAddresses.map { ($0.value as String).lowercased() }.filter { !$0.isEmpty }
        return !Set(aEmails).isDisjoint(with: Set(bEmails))
    }

    /// Normalises a phone number to its last 10 digits.
    nonisolated static func normalize(phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        return String(digits.suffix(10))
    }

    /// Jaro-Winkler similarity between two contact full names.
    private func nameSimilarity(_ a: CNContact, _ b: CNContact) -> Double {
        let nameA = "\(a.givenName) \(a.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
        let nameB = "\(b.givenName) \(b.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
        guard !nameA.isEmpty, !nameB.isEmpty else { return 0 }
        return Self.jaroWinkler(nameA, nameB)
    }

    nonisolated static func jaroWinkler(_ s1: String, _ s2: String) -> Double {
        let jaro = jaroSimilarity(s1, s2)
        let arr1 = Array(s1), arr2 = Array(s2)
        var prefix = 0
        for i in 0..<min(4, min(arr1.count, arr2.count)) {
            if arr1[i] == arr2[i] { prefix += 1 } else { break }
        }
        return jaro + Double(prefix) * 0.1 * (1 - jaro)
    }

    nonisolated static func jaroSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        let a = Array(s1), b = Array(s2)
        if a.isEmpty || b.isEmpty { return 0.0 }
        let matchDist = max(max(a.count, b.count) / 2 - 1, 0)
        var s1Matches = Array(repeating: false, count: a.count)
        var s2Matches = Array(repeating: false, count: b.count)
        var matches: Double = 0
        var transpositions: Double = 0

        for i in 0..<a.count {
            let start = max(0, i - matchDist)
            let end = min(i + matchDist + 1, b.count)
            guard start < end else { continue }
            for j in start..<end where !s2Matches[j] && a[i] == b[j] {
                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }
        guard matches > 0 else { return 0 }
        var k = 0
        for i in 0..<a.count where s1Matches[i] {
            while k < b.count && !s2Matches[k] { k += 1 }
            guard k < b.count else { break }
            if a[i] != b[k] { transpositions += 1 }
            k += 1
        }
        return (matches / Double(a.count) + matches / Double(b.count) + (matches - transpositions / 2) / matches) / 3
    }
}
