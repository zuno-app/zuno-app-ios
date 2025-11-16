import SwiftUI
import SwiftData

/// Zuno tag input screen for registration or login
struct ZunoTagInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel: AuthViewModel

    let isRegistration: Bool

    @State private var zunoTag: String = ""
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var validationMessage: String?
    @State private var showingPasskeySetup = false
    @FocusState private var focusedField: Field?

    init(isRegistration: Bool) {
        self.isRegistration = isRegistration
        // Note: ViewModel will be properly initialized in onAppear with modelContext
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: ModelContext(ModelContainer.preview)))
    }

    enum Field {
        case zunoTag, displayName, email
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: isRegistration ? "person.badge.plus" : "person.badge.key")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text(isRegistration ? "Create Your @zuno Tag" : "Welcome Back")
                            .font(.title.bold())

                        Text(isRegistration ? "Choose a unique @zuno tag for payments" : "Enter your @zuno tag to sign in")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 24) {
                        // Zuno Tag Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@zuno Tag")
                                .font(.headline)

                            HStack {
                                Text("@")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                TextField("yourtag", text: $zunoTag)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .zunoTag)
                                    .font(.title3)
                                    .onChange(of: zunoTag) { _, newValue in
                                        // Auto-validate while typing
                                        validateZunoTag()
                                    }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                            if let message = validationMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Text("3-50 characters, lowercase letters, numbers, and underscores only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Display Name (Registration only)
                        if isRegistration {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name (Optional)")
                                    .font(.headline)

                                TextField("Your Name", text: $displayName)
                                    .focused($focusedField, equals: .displayName)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }

                            // Email (Registration only)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email (Optional)")
                                    .font(.headline)

                                TextField("your@email.com", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .focused($focusedField, equals: .email)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    // Continue Button
                    Button(action: {
                        handleContinue()
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(16)
                    }
                    .disabled(!isFormValid || authViewModel.isLoading)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize view model with proper modelContext
            focusedField = .zunoTag
        }
        .navigationDestination(isPresented: $showingPasskeySetup) {
            PasskeySetupView(
                zunoTag: zunoTag,
                displayName: displayName.isEmpty ? nil : displayName,
                email: email.isEmpty ? nil : email,
                isRegistration: isRegistration
            )
        }
        .alert("Error", isPresented: $authViewModel.showError) {
            Button("OK") {
                authViewModel.clearError()
            }
        } message: {
            if let error = authViewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let validation = authViewModel.validateZunoTag(zunoTag)
        return validation.isValid
    }

    private func validateZunoTag() {
        let validation = authViewModel.validateZunoTag(zunoTag)
        validationMessage = validation.errorMessage
    }

    private func handleContinue() {
        guard isFormValid else { return }

        // Move to passkey setup
        showingPasskeySetup = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ZunoTagInputView(isRegistration: true)
            .modelContainer(ModelContainer.preview)
    }
}

#Preview("Login") {
    NavigationStack {
        ZunoTagInputView(isRegistration: false)
            .modelContainer(ModelContainer.preview)
    }
}

// MARK: - Preview Container

extension ModelContainer {
    static var preview: ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: LocalUser.self, LocalWallet.self, LocalTransaction.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
