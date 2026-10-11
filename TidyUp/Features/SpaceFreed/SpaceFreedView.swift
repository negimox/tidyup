import SwiftUI

/// Celebratory screen shown after successful deletion.
struct SpaceFreedView: View {
    let itemCount: Int
    let contactsMerged: Int
    var freedBytes: Int64 = 0
    var onReturnToHome: (() -> Void)? = nil

    @State private var showCheckmark = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.spacing32) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Theme.bestGreen.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.bestGreen)
                    .scaleEffect(showCheckmark ? 1 : 0.3)
                    .opacity(showCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
            }

            VStack(spacing: Theme.spacing12) {
                if freedBytes > 0 {
                    Text("\(freedBytes, format: .byteCount(style: .file)) freed")
                        .font(.largeTitle)
                        .bold()
                } else {
                    Text("All Clean!")
                        .font(.largeTitle)
                        .bold()
                }

                if itemCount > 0 {
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s") moved to Recently Deleted")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if contactsMerged > 0 {
                    Text("\(contactsMerged) contact group\(contactsMerged == 1 ? "" : "s") merged")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Theme.spacing32)

            // Guidance note
            if itemCount > 0 {
                GroupBox {
                    Label(
                        "To reclaim storage now, open Photos → Albums → Recently Deleted → Delete All.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.spacing20)
            }

            Spacer()

            Button("Done", systemImage: "checkmark") {
                if let onReturnToHome {
                    onReturnToHome()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, Theme.spacing32)
            .padding(.bottom, Theme.spacing32)
        }
        .navigationTitle("Space Freed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .onAppear {
            showCheckmark = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
