import Foundation
import SwiftData
import Combine
import AuthenticationServices

/// Service for authentication and user management
@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: LocalUser?
    @Published var isAuthenticated: Bool = false

    private let modelContext: ModelContext
    private let passkeyService = PasskeyAuthService.shared
    private let biometricService = BiometricAuthService.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Authentication Status

    /// Check if user is authenticated by validating stored token
    func checkAuthStatus() async {
        do {
            // Check if we have a valid access token
            let token = try KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.accessToken)

            guard !token.isEmpty else {
                await logout()
                return
            }

            // Try to fetch current user from API
            let userResponse = try await APIClient.shared.getCurrentUser()

            // Save or update user in local database
            let localUser = try await saveUser(userResponse)
            self.currentUser = localUser
            self.isAuthenticated = true

        } catch {
            // Token invalid or expired
            await logout()
        }
    }

    // MARK: - Registration

    /// Register a new user with passkey
    /// - Parameters:
    ///   - zunoTag: The @zuno tag for the user
    ///   - displayName: User's display name
    ///   - email: Optional email address
    ///   - window: The window to present passkey UI
    func register(
        zunoTag: String,
        displayName: String?,
        email: String? = nil,
        window: ASPresentationAnchor
    ) async throws -> LocalUser {
        // Validate zuno tag format
        guard isValidZunoTag(zunoTag) else {
            throw AuthError.invalidZunoTag
        }

        // Start passkey registration
        let authResponse = try await passkeyService.register(
            zunoTag: zunoTag,
            displayName: displayName,
            window: window
        )

        // Save user data
        let localUser = try await saveUser(authResponse.user)

        // Save user ID and zuno tag to keychain
        try KeychainManager.shared.save(authResponse.user.id, forKey: Config.KeychainKeys.userID)
        try KeychainManager.shared.save(zunoTag, forKey: Config.KeychainKeys.zunoTag)

        // Update auth state
        self.currentUser = localUser
        self.isAuthenticated = true

        return localUser
    }

    // MARK: - Login

    /// Login with passkey
    /// - Parameters:
    ///   - zunoTag: The @zuno tag to authenticate
    ///   - window: The window to present passkey UI
    func login(zunoTag: String, window: ASPresentationAnchor) async throws -> LocalUser {
        // Validate zuno tag format
        guard isValidZunoTag(zunoTag) else {
            throw AuthError.invalidZunoTag
        }

        // Start passkey authentication
        let authResponse = try await passkeyService.authenticate(
            zunoTag: zunoTag,
            window: window
        )

        // Save user data
        let localUser = try await saveUser(authResponse.user)

        // Save user ID and zuno tag to keychain
        try KeychainManager.shared.save(authResponse.user.id, forKey: Config.KeychainKeys.userID)
        try KeychainManager.shared.save(zunoTag, forKey: Config.KeychainKeys.zunoTag)

        // Update auth state
        self.currentUser = localUser
        self.isAuthenticated = true

        return localUser
    }

    // MARK: - Biometric Quick Login

    /// Quick login with biometrics (requires prior passkey login)
    func quickLogin() async throws -> LocalUser {
        // Check if biometric authentication is available
        guard biometricService.biometricsAvailable else {
            throw AuthError.biometricsNotAvailable
        }

        // Authenticate with biometrics
        let authenticated = try await biometricService.authenticate()
        guard authenticated else {
            throw AuthError.biometricAuthenticationFailed
        }

        // Check if we have stored credentials
        guard let userId = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.userID),
              let zunoTag = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.zunoTag),
              !userId.isEmpty, !zunoTag.isEmpty else {
            throw AuthError.noStoredCredentials
        }

        // Fetch current user from API
        let userResponse = try await APIClient.shared.getCurrentUser()

        // Save or update user in local database
        let localUser = try await saveUser(userResponse)

        // Update auth state
        self.currentUser = localUser
        self.isAuthenticated = true

        return localUser
    }

    // MARK: - Logout

    /// Logout the current user
    func logout() async {
        // Clear tokens from keychain
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.accessToken)
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.refreshToken)

        // Update auth state
        self.currentUser = nil
        self.isAuthenticated = false
    }

    // MARK: - User Profile Management

    /// Update current user profile
    func updateProfile(
        email: String? = nil,
        displayName: String? = nil,
        defaultCurrency: String? = nil,
        preferredNetwork: String? = nil
    ) async throws -> LocalUser {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        // Update profile via API
        let updatedUser = try await APIClient.shared.updateUser(
            email: email,
            displayName: displayName,
            defaultCurrency: defaultCurrency,
            preferredNetwork: preferredNetwork
        )

        // Save updated user in local database
        let localUser = try await saveUser(updatedUser)
        self.currentUser = localUser

        return localUser
    }

    /// Refresh current user data from API
    func refreshUser() async throws -> LocalUser {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        let userResponse = try await APIClient.shared.getCurrentUser()
        let localUser = try await saveUser(userResponse)
        self.currentUser = localUser

        return localUser
    }

    // MARK: - Helper Methods

    /// Save or update user in local database
    private func saveUser(_ userResponse: UserResponse) async throws -> LocalUser {
        // Check if user already exists
        let descriptor = FetchDescriptor<LocalUser>(
            predicate: #Predicate { $0.id == userResponse.id }
        )
        let existingUsers = try modelContext.fetch(descriptor)

        if let existingUser = existingUsers.first {
            // Update existing user
            existingUser.zunoTag = userResponse.zunoTag
            existingUser.email = userResponse.email
            existingUser.displayName = userResponse.displayName
            existingUser.defaultCurrency = userResponse.defaultCurrency ?? Config.App.defaultCurrency
            existingUser.preferredNetwork = userResponse.preferredNetwork ?? Config.App.defaultNetwork
            existingUser.isVerified = userResponse.isVerified
            existingUser.updatedAt = Date()
            try modelContext.save()
            return existingUser
        } else {
            // Create new user
            let newUser = LocalUser.from(userResponse)
            modelContext.insert(newUser)
            try modelContext.save()
            return newUser
        }
    }

    /// Validate zuno tag format
    private func isValidZunoTag(_ tag: String) -> Bool {
        // Remove @ prefix if present
        let cleanTag = tag.hasPrefix("@") ? String(tag.dropFirst()) : tag

        // Must be 3-50 characters, lowercase alphanumeric and underscore only
        let pattern = "^[a-z0-9_]{3,50}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: cleanTag.utf16.count)
        return regex?.firstMatch(in: cleanTag, range: range) != nil
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidZunoTag
    case registrationFailed
    case loginFailed
    case biometricsNotAvailable
    case biometricAuthenticationFailed
    case noStoredCredentials
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .invalidZunoTag:
            return "Invalid @zuno tag. Must be 3-50 characters, lowercase letters, numbers, and underscores only."
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .loginFailed:
            return "Login failed. Please try again."
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed."
        case .noStoredCredentials:
            return "No stored credentials found. Please log in with your passkey."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        }
    }
}
