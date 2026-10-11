import SwiftUI
import Contacts

/// Shows a preview of what the merged contact will look like.
struct ContactMergePreviewView: View {
    let group: DuplicateContactGroup
    @Environment(\.dismiss) private var dismiss

    private var mergedPhones: [String] {
        var seen = Set<String>()
        var result: [String] = []
        let all = [group.primary] + group.duplicates
        for c in all {
            for p in c.phoneNumbers {
                let val = p.value.stringValue
                if seen.insert(val).inserted { result.append(val) }
            }
        }
        return result
    }

    private var mergedEmails: [String] {
        var seen = Set<String>()
        var result: [String] = []
        let all = [group.primary] + group.duplicates
        for c in all {
            for e in c.emailAddresses {
                let val = e.value as String
                if seen.insert(val).inserted { result.append(val) }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Primary Contact") {
                    Text("\(group.primary.givenName) \(group.primary.familyName)")
                        .font(.headline)
                }

                Section("Merged Phone Numbers") {
                    if mergedPhones.isEmpty {
                        Text("None").foregroundStyle(.secondary)
                    } else {
                        ForEach(mergedPhones, id: \.self) { phone in
                            Text(phone)
                        }
                    }
                }

                Section("Merged Emails") {
                    if mergedEmails.isEmpty {
                        Text("None").foregroundStyle(.secondary)
                    } else {
                        ForEach(mergedEmails, id: \.self) { email in
                            Text(email)
                        }
                    }
                }

                Section("Duplicates to Delete") {
                    ForEach(group.duplicates, id: \.identifier) { dup in
                        Text("\(dup.givenName) \(dup.familyName)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Label(
                        "Contact merges are permanent and cannot be undone.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(Theme.deleteRed)
                    .font(.caption)
                }
            }
            .navigationTitle("Merge Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
