import SwiftUI
import Contacts

struct DuplicateContactsView: View {
    let groups: [DuplicateContactGroup]
    var onReturnToHome: (() -> Void)? = nil
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var showReview = false
    @State private var mergePreviewGroup: DuplicateContactGroup?

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Duplicate Contacts",
                    systemImage: "person.2.badge.gearshape",
                    description: Text("Your contacts look clean!")
                )
            } else {
                List(groups) { group in
                    ContactGroupRow(
                        group: group,
                        isSelected: selectedGroupIDs.contains(group.id),
                        onToggle: { toggle(group.id) },
                        onPreview: { mergePreviewGroup = group }
                    )
                }
                .listStyle(.plain)

                SelectionToolbar(
                    selectedCount: selectedGroupIDs.count,
                    selectedBytes: 0,
                    actionTitle: "Review & Merge"
                ) {
                    showReview = true
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $mergePreviewGroup) { group in
            ContactMergePreviewView(group: group)
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewDeleteView(
                selectedPhotoIDs: [],
                allAssets: [],
                contactGroups: groups.filter { selectedGroupIDs.contains($0.id) },
                onReturnToHome: onReturnToHome
            )
        }
    }

    private func toggle(_ id: UUID) {
        if selectedGroupIDs.contains(id) { selectedGroupIDs.remove(id) } else { selectedGroupIDs.insert(id) }
    }
}

// MARK: - Row

private struct ContactGroupRow: View {
    let group: DuplicateContactGroup
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    var fullName: String {
        "\(group.primary.givenName) \(group.primary.familyName)".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.primary : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(fullName.isEmpty ? "Unknown" : fullName)
                    .font(.headline)
                Text("\(group.duplicates.count) duplicate\(group.duplicates.count == 1 ? "" : "s") · \(reasonLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Preview", action: onPreview)
                .font(.caption)
                .buttonStyle(.glass)
        }
        .padding(.vertical, Theme.spacing8)
        .accessibilityElement(children: .combine)
    }

    private var reasonLabel: String {
        switch group.matchReason {
        case .phone: "same phone"
        case .email: "same email"
        case .name: "similar name"
        }
    }
}
