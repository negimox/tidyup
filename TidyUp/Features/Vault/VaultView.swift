import SwiftUI
import LocalAuthentication
import Photos

/// PIN or Face ID protected private vault.
struct VaultView: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    @State private var isAuthenticating = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing24) {
                if isUnlocked {
                    VaultUnlockedView()
                } else {
                    VaultLockedView(
                        authError: authError,
                        isAuthenticating: isAuthenticating,
                        onUnlock: { Task { await authenticate() } }
                    )
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lock", systemImage: "lock.fill") {
                            withAnimation { isUnlocked = false }
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    // Auto-lock when leaving foreground
                    isUnlocked = false
                }
            }
        }
    }

    // MARK: - Authentication

    private func authenticate() async {
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock your private vault"
                )
                if success {
                    withAnimation {
                        isUnlocked = true
                    }
                }
            } catch {
                authError = error.localizedDescription
            }
        } else {
            authError = error?.localizedDescription ?? "Biometrics or passcode not available."
        }

        isAuthenticating = false
    }
}

// MARK: - Subview Structs

private struct VaultLockedView: View {
    let authError: String?
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primary)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: Theme.spacing8) {
                Text("Private Vault")
                    .font(.title2)
                    .bold()

                Text("Keep sensitive photos and videos secure on your device behind Face ID.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing32)
            }

            if let authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(Theme.deleteRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacing24)
            }

            Spacer()

            Button("Unlock with Biometrics", systemImage: "faceid", action: onUnlock)
                .buttonStyle(.glassProminent)
                .padding(.horizontal, Theme.spacing32)
                .padding(.bottom, Theme.spacing32)
                .disabled(isAuthenticating)
        }
    }
}

private struct VaultUnlockedView: View {
    var body: some View {
        VStack(spacing: Theme.spacing16) {
            ContentUnavailableView(
                "Vault is Empty",
                systemImage: "photo.stack",
                description: Text("Items you move to the Vault stay encrypted and hidden from your general photo library.")
            )

            Spacer()

            Button("Add Private Items", systemImage: "plus") {
                // Future expansion: Pick assets to hide
            }
            .buttonStyle(.glass)
            .padding(.bottom, Theme.spacing32)
        }
    }
}
