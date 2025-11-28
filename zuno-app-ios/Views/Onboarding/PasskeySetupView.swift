import SwiftUI
import SwiftData
import AuthenticationServices

/// Passkey setup screen for registration or login
struct PasskeySetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    let zunoTag: String
    let displayName: String?
    let email: String?
    let isRegistration: Bool

    @State private var isAuthenticating = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var isUserAlreadyExists = false
    @State private var passkeyName: String = ""
    @FocusState private var isNameFieldFocused: Bool

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

                // Passkey name input (optional)
                if isRegistration {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name Your Passkey (Optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)
                        
                        TextField("e.g., My iPhone, Work Phone", text: $passkeyName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 32)
                            .focused($isNameFieldFocused)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                    }
                }

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
        .navigationBarBackButtonHidden(isAuthenticating || showError)
        .interactiveDismissDisabled(showError)
        .alert("Success", isPresented: $showSuccess) {
            Button("Continue") {
                // Navigation will be handled by AuthViewModel state change
            }
        } message: {
            Text(isRegistration ? "Your wallet has been created!" : "Welcome back!")
        }
        .alert("Error", isPresented: $showError) {
            // Show "Login Instead" button if user already exists
            if errorMessage?.contains("already registered") == true {
                Button("Login Instead") {
                    // Navigate to login with the same zuno tag
                    dismiss()
                    // The WelcomeView will handle showing login
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } else {
                Button("Try Again") {
                    errorMessage = nil
                    showError = false
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            } else {
                Text("An error occurred during authentication")
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
        errorMessage = nil
        showError = false

        Task {
            do {
                // Get the window for presenting passkey UI
                guard let window = await getWindow() else {
                    print("❌ [PasskeySetup] Could not get window")
                    throw PasskeyError.registrationFailed("Could not get window")
                }

                print("🔐 [PasskeySetup] Starting \(isRegistration ? "registration" : "login") for @\(zunoTag)")

                if isRegistration {
                    // Register new user
                    // Use passkey name if provided, otherwise use device name
                    let deviceName = passkeyName.isEmpty ? UIDevice.current.name : passkeyName
                    print("🔐 [PasskeySetup] Using device name: \(deviceName)")
                    
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

                // Check if authentication succeeded
                if authViewModel.isAuthenticated {
                    print("✅ [PasskeySetup] Authentication successful")
                    await MainActor.run {
                        showSuccess = true
                    }
                } else {
                    // Authentication failed - check if ViewModel has error
                    print("⚠️ [PasskeySetup] Authentication failed")
                    await MainActor.run {
                        if let viewModelError = authViewModel.errorMessage {
                            print("⚠️ [PasskeySetup] Using ViewModel error: \(viewModelError)")
                            errorMessage = viewModelError
                            showError = true
                        } else {
                            print("⚠️ [PasskeySetup] No error message from ViewModel")
                            errorMessage = "Authentication failed. Please try again."
                            showError = true
                        }
                    }
                    // Clear the ViewModel error so it doesn't interfere
                    authViewModel.clearError()
                }

            } catch let error as PasskeyError {
                print("❌ [PasskeySetup] PasskeyError: \(error.localizedDescription)")
                // Build detailed error message with recovery suggestion
                var message = error.localizedDescription
                if let suggestion = error.recoverySuggestion {
                    message += "\n\n\(suggestion)"
                }
                await MainActor.run {
                    errorMessage = message
                    showError = true
                    print("🚨 [PasskeySetup] Alert should show now - showError: \(showError)")
                }
                
            } catch {
                print("❌ [PasskeySetup] Unknown error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)\n\nPlease try again."
                    showError = true
                    print("🚨 [PasskeySetup] Alert should show now - showError: \(showError)")
                }
            }

            await MainActor.run {
                isAuthenticating = false
            }
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

@available(iOS 17.0, *)
struct PasskeySetupView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([LocalUser.self, LocalWallet.self, LocalTransaction.self, CachedData.self, AppSettings.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let authViewModel = AuthViewModel(modelContext: container.mainContext)

        Group {
            NavigationStack {
                PasskeySetupView(
                    zunoTag: "alice",
                    displayName: "Alice",
                    email: "alice@example.com",
                    isRegistration: true
                )
                .environmentObject(authViewModel)
                .modelContainer(container)
            }
            .previewDisplayName("Registration")

            NavigationStack {
                PasskeySetupView(
                    zunoTag: "alice",
                    displayName: nil,
                    email: nil,
                    isRegistration: false
                )
                .environmentObject(authViewModel)
                .modelContainer(container)
            }
            .previewDisplayName("Login")
        }
    }
}
