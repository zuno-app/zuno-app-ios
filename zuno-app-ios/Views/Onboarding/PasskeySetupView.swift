import SwiftUI
import SwiftData
import AuthenticationServices

/// Passkey setup screen for registration or login
struct PasskeySetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel: AuthViewModel

    let zunoTag: String
    let displayName: String?
    let email: String?
    let isRegistration: Bool

    @State private var isAuthenticating = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?

    init(zunoTag: String, displayName: String?, email: String?, isRegistration: Bool) {
        self.zunoTag = zunoTag
        self.displayName = displayName
        self.email = email
        self.isRegistration = isRegistration
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: ModelContext(ModelContainer.preview)))
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Biometric icon
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)

                        Image(systemName: getBiometricIcon())
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                    }

                    Text(isRegistration ? "Secure Your Wallet" : "Authenticate")
                        .font(.title.bold())

                    Text(isRegistration ? "Register your passkey to secure your wallet" : "Use your passkey to sign in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Info cards
                VStack(spacing: 16) {
                    InfoCard(
                        icon: "key.fill",
                        title: "Passwordless",
                        description: "No passwords to remember"
                    )

                    InfoCard(
                        icon: "lock.shield.fill",
                        title: "Secure",
                        description: "Protected by biometric authentication"
                    )

                    InfoCard(
                        icon: "bolt.fill",
                        title: "Fast",
                        description: "Quick access with Face ID or Touch ID"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Action button
                VStack(spacing: 16) {
                    Button(action: {
                        handleAuthentication()
                    }) {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: getBiometricIcon())
                                Text(isRegistration ? "Register Passkey" : "Sign In with Passkey")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .disabled(isAuthenticating)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Back")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(isAuthenticating)
        .alert("Success", isPresented: $showSuccess) {
            Button("Continue") {
                // Navigation will be handled by AuthViewModel state change
            }
        } message: {
            Text(isRegistration ? "Your wallet has been created!" : "Welcome back!")
        }
        .alert("Error", isPresented: $showError) {
            Button("Try Again") {
                errorMessage = nil
                showError = false
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Helper Methods

    private func getBiometricIcon() -> String {
        let biometricType = BiometricAuthService.shared.biometricType
        return biometricType.icon
    }

    private func handleAuthentication() {
        isAuthenticating = true

        Task {
            do {
                // Get the window for presenting passkey UI
                guard let window = await getWindow() else {
                    throw PasskeyError.registrationFailed("Could not get window")
                }

                if isRegistration {
                    // Register new user
                    await authViewModel.register(
                        zunoTag: zunoTag,
                        displayName: displayName,
                        email: email,
                        window: window
                    )
                } else {
                    // Login existing user
                    await authViewModel.login(
                        zunoTag: zunoTag,
                        window: window
                    )
                }

                if authViewModel.isAuthenticated {
                    showSuccess = true
                }

            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isAuthenticating = false
        }
    }

    @MainActor
    private func getWindow() async -> ASPresentationAnchor? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window
    }
}

// MARK: - Info Card Component

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PasskeySetupView(
            zunoTag: "alice",
            displayName: "Alice",
            email: "alice@example.com",
            isRegistration: true
        )
        .modelContainer(ModelContainer.preview)
    }
}

#Preview("Login") {
    NavigationStack {
        PasskeySetupView(
            zunoTag: "alice",
            displayName: nil,
            email: nil,
            isRegistration: false
        )
        .modelContainer(ModelContainer.preview)
    }
}
