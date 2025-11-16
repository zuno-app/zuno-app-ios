import Foundation
import SwiftData
import AuthenticationServices

/// ViewModel for authentication flows
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: LocalUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private let authService: AuthService
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.authService = AuthService(modelContext: modelContext)

        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Authentication Status

    /// Check authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        await authService.checkAuthStatus()
        self.isAuthenticated = authService.isAuthenticated
        self.currentUser = authService.currentUser
        isLoading = false
    }

    // MARK: - Registration

    /// Start registration flow
    func register(zunoTag: String, displayName: String?, email: String? = nil, window: ASPresentationAnchor) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let user = try await authService.register(
                zunoTag: zunoTag,
                displayName: displayName,
                email: email,
                window: window
            )

            self.currentUser = user
            self.isAuthenticated = true

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    /// Validate zuno tag (client-side check before API call)
    func validateZunoTag(_ tag: String) -> ValidationResult {
        // Remove @ prefix if present
        let cleanTag = tag.hasPrefix("@") ? String(tag.dropFirst()) : tag

        // Check length
        guard cleanTag.count >= 3 else {
            return .invalid("@zuno tag must be at least 3 characters")
        }

        guard cleanTag.count <= 50 else {
            return .invalid("@zuno tag must be 50 characters or less")
        }

        // Check format (lowercase alphanumeric and underscore only)
        let pattern = "^[a-z0-9_]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: cleanTag.utf16.count)

        guard regex?.firstMatch(in: cleanTag, range: range) != nil else {
            return .invalid("@zuno tag can only contain lowercase letters, numbers, and underscores")
        }

        return .valid
    }

    // MARK: - Login

    /// Start login flow with passkey
    func login(zunoTag: String, window: ASPresentationAnchor) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let user = try await authService.login(zunoTag: zunoTag, window: window)

            self.currentUser = user
            self.isAuthenticated = true

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    /// Quick login with biometrics (after prior passkey login)
    func quickLogin() async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let user = try await authService.quickLogin()

            self.currentUser = user
            self.isAuthenticated = true

        } catch {
            // If quick login fails, fall back to passkey login
            self.errorMessage = "Biometric authentication failed. Please use your passkey."
            self.showError = true
        }

        isLoading = false
    }

    // MARK: - Logout

    /// Logout current user
    func logout() async {
        isLoading = true
        await authService.logout()
        self.isAuthenticated = false
        self.currentUser = nil
        isLoading = false
    }

    // MARK: - Profile Management

    /// Update user profile
    func updateProfile(email: String? = nil, displayName: String? = nil, defaultCurrency: String? = nil, preferredNetwork: String? = nil) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let updatedUser = try await authService.updateProfile(
                email: email,
                displayName: displayName,
                defaultCurrency: defaultCurrency,
                preferredNetwork: preferredNetwork
            )

            self.currentUser = updatedUser

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    /// Refresh user data from API
    func refreshUser() async {
        guard isAuthenticated else { return }

        do {
            let user = try await authService.refreshUser()
            self.currentUser = user
        } catch {
            // Silent error - user data refresh failed
            print("Failed to refresh user: \(error)")
        }
    }

    // MARK: - Error Handling

    /// Clear error message
    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}
