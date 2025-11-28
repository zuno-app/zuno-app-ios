import SwiftUI
import SwiftData
import Combine

/// Zuno tag input screen for registration or login
struct ZunoTagInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    let isRegistration: Bool

    @State private var zunoTag: String = ""
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var validationMessage: String?
    @State private var isCheckingAvailability: Bool = false
    @State private var isTagAvailable: Bool? = nil
    @State private var isCheckingEmailAvailability: Bool = false
    @State private var isEmailAvailable: Bool? = nil
    @State private var emailValidationMessage: String?
    @State private var showingPasskeySetup = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var emailDebounceTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

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
                                        // Reset availability and check with debounce
                                        isTagAvailable = nil
                                        if isRegistration {
                                            checkAvailabilityDebounced()
                                        }
                                    }
                                
                                // Availability indicator
                                if isCheckingAvailability {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if let available = isTagAvailable {
                                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(available ? .green : .red)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                            if let message = validationMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if isTagAvailable == false {
                                Text("This @zuno tag is already taken")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if isTagAvailable == true {
                                Text("This @zuno tag is available!")
                                    .font(.caption)
                                    .foregroundStyle(.green)
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

                                HStack {
                                    TextField("your@email.com", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.emailAddress)
                                        .focused($focusedField, equals: .email)
                                        .font(.body)
                                        .onChange(of: email) { _, _ in
                                            // Reset availability and check with debounce
                                            isEmailAvailable = nil
                                            emailValidationMessage = nil
                                            if !email.isEmpty {
                                                checkEmailAvailabilityDebounced()
                                            }
                                        }
                                    
                                    // Email availability indicator
                                    if isCheckingEmailAvailability {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if let available = isEmailAvailable {
                                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(available ? .green : .red)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                
                                if let message = emailValidationMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else if isEmailAvailable == false {
                                    Text("This email is already registered")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else if isEmailAvailable == true && !email.isEmpty {
                                    Text("Email is available")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
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
        // For registration, also require availability check
        if isRegistration {
            let tagValid = validation.isValid && isTagAvailable == true
            // Email is optional, but if provided must be valid and available
            let emailValid = email.isEmpty || (isValidEmail(email) && isEmailAvailable != false)
            return tagValid && emailValid
        }
        return validation.isValid
    }

    private func validateZunoTag() {
        let validation = authViewModel.validateZunoTag(zunoTag)
        validationMessage = validation.errorMessage
    }
    
    /// Debounced availability check - waits 500ms after user stops typing
    private func checkAvailabilityDebounced() {
        // Cancel any existing debounce task
        debounceTask?.cancel()
        
        let validation = authViewModel.validateZunoTag(zunoTag)
        guard validation.isValid else {
            isTagAvailable = nil
            isCheckingAvailability = false
            return
        }
        
        // Show loading indicator
        isCheckingAvailability = true
        
        // Create new debounce task
        debounceTask = Task {
            // Wait 500ms before checking
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await checkTagAvailability()
        }
    }
    
    /// Check if zuno tag is available (for registration only)
    private func checkTagAvailability() async {
        guard isRegistration else { return }
        
        let currentTag = zunoTag
        let validation = authViewModel.validateZunoTag(currentTag)
        guard validation.isValid else {
            await MainActor.run {
                isTagAvailable = nil
                isCheckingAvailability = false
            }
            return
        }
        
        do {
            // Use the dedicated availability check endpoint
            let available = try await APIClient.shared.checkZunoTagAvailability(currentTag)
            await MainActor.run {
                // Only update if tag hasn't changed while checking
                if zunoTag == currentTag {
                    isTagAvailable = available
                    isCheckingAvailability = false
                }
            }
        } catch {
            // On error, assume available and let registration handle it
            print("⚠️ [ZunoTagInput] Error checking availability: \(error)")
            await MainActor.run {
                if zunoTag == currentTag {
                    isTagAvailable = true
                    isCheckingAvailability = false
                }
            }
        }
    }

    // MARK: - Email Validation
    
    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return true } // Empty is OK (optional field)
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// Debounced email availability check - waits 500ms after user stops typing
    private func checkEmailAvailabilityDebounced() {
        // Cancel any existing debounce task
        emailDebounceTask?.cancel()
        
        guard !email.isEmpty else {
            isEmailAvailable = nil
            isCheckingEmailAvailability = false
            emailValidationMessage = nil
            return
        }
        
        // Validate email format first
        guard isValidEmail(email) else {
            isEmailAvailable = nil
            isCheckingEmailAvailability = false
            emailValidationMessage = "Please enter a valid email address"
            return
        }
        
        // Show loading indicator
        isCheckingEmailAvailability = true
        emailValidationMessage = nil
        
        // Create new debounce task
        emailDebounceTask = Task {
            // Wait 500ms before checking
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await checkEmailAvailability()
        }
    }
    
    /// Check if email is available (for registration only)
    private func checkEmailAvailability() async {
        guard isRegistration else { return }
        
        let currentEmail = email
        guard !currentEmail.isEmpty && isValidEmail(currentEmail) else {
            await MainActor.run {
                isEmailAvailable = nil
                isCheckingEmailAvailability = false
            }
            return
        }
        
        do {
            // Use the dedicated availability check endpoint
            let available = try await APIClient.shared.checkEmailAvailability(currentEmail)
            await MainActor.run {
                // Only update if email hasn't changed while checking
                if email == currentEmail {
                    isEmailAvailable = available
                    isCheckingEmailAvailability = false
                }
            }
        } catch {
            // On error, assume available and let registration handle it
            print("⚠️ [ZunoTagInput] Error checking email availability: \(error)")
            await MainActor.run {
                if email == currentEmail {
                    isEmailAvailable = true
                    isCheckingEmailAvailability = false
                }
            }
        }
    }

    private func handleContinue() {
        guard isFormValid else { return }

        // Move to passkey setup
        showingPasskeySetup = true
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct ZunoTagInputView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([LocalUser.self, LocalWallet.self, LocalTransaction.self, CachedData.self, AppSettings.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let authViewModel = AuthViewModel(modelContext: container.mainContext)

        Group {
            NavigationStack {
                ZunoTagInputView(isRegistration: true)
                    .environmentObject(authViewModel)
                    .modelContainer(container)
            }
            .previewDisplayName("Registration")

            NavigationStack {
                ZunoTagInputView(isRegistration: false)
                    .environmentObject(authViewModel)
                    .modelContainer(container)
            }
            .previewDisplayName("Login")
        }
    }
}


