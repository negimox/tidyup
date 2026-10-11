import SwiftUI

/// Sticky bottom selection toolbar showing count + CTA.
struct SelectionToolbar: View {
    let selectedCount: Int
    let selectedBytes: Int64
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCount) selected")
                    .font(.headline)
                    .contentTransition(.numericText())
                if selectedBytes > 0 {
                    Text(selectedBytes, format: .byteCount(style: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            Button(actionTitle, action: action)
                .buttonStyle(.glassProminent)
                .disabled(selectedCount == 0)
        }
        .padding(.horizontal, Theme.spacing20)
        .padding(.vertical, Theme.spacing16)
        .background(.regularMaterial)
    }
}
