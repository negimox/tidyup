import Contacts
import Foundation

/// The reason two contacts were flagged as duplicates.
enum MatchReason: Sendable {
    case phone
    case email
    case name
}

/// A group of contacts that appear to be duplicates of each other.
struct DuplicateContactGroup: Identifiable, Sendable {
    let id: UUID
    /// The contact chosen as the "primary" to merge into.
    var primary: CNContact
    /// All other contacts in the group to be merged or deleted.
    var duplicates: [CNContact]
    var matchReason: MatchReason

    init(id: UUID = UUID(), primary: CNContact, duplicates: [CNContact], matchReason: MatchReason) {
        self.id = id
        self.primary = primary
        self.duplicates = duplicates
        self.matchReason = matchReason
    }
}
