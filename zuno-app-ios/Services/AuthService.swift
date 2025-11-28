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
    /// NOTE: This only checks if credentials EXIST, it does NOT auto-login
    /// User must authenticate via biometrics or passkey to actually login
    func checkAuthStatus() async {
        print("🔐 [AuthService] Checking auth status...")
        
        // Check if we have stored credentials
        let hasToken = KeychainManager.shared.exists(forKey: Config.KeychainKeys.accessToken)
        let hasUserID = KeychainManager.shared.exists(forKey: Config.KeychainKeys.userID)
        
        print("   Has token: \(hasToken), Has userID: \(hasUserID)")
        
        // SECURITY: Do NOT auto-login even if credentials exist
        // User must authenticate via biometrics or passkey
        // This prevents unauthorized access if someone has physical access to the device
        
        if !hasToken || !hasUserID {
            print("⚠️ [AuthService] No stored credentials - user must register/login")
        } else {
            print("🔐 [AuthService] Credentials found - user must authenticate with biometrics")
        }
        
        // Always start as not authenticated - require explicit authentication
        self.isAuthenticated = false
        self.currentUser = nil
    }
    
    /// Check if user has stored credentials (for showing appropriate login UI)
    func hasStoredCredentials() -> Bool {
        let hasToken = KeychainManager.shared.exists(forKey: Config.KeychainKeys.accessToken)
        let hasUserID = KeychainManager.shared.exists(forKey: Config.KeychainKeys.userID)
        return hasToken && hasUserID
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
            email: email,
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

    /// Quick login after biometric authentication has already been verified
    /// This method assumes biometric auth was already done by the caller
    func quickLogin() async throws -> LocalUser {
        print("🔐 [AuthService] Quick login - loading user from stored credentials")
        
        // Check if we have stored credentials
        guard let userId = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.userID),
              !userId.isEmpty else {
            print("❌ [AuthService] No stored user ID")
            throw AuthError.noStoredCredentials
        }
        
        // Get stored zuno tag for logging
        let zunoTag = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.zunoTag)
        print("🔐 [AuthService] Found stored credentials for @\(zunoTag ?? "unknown")")

        // Fetch current user from API
        do {
            let userResponse = try await APIClient.shared.getCurrentUser()
            print("✅ [AuthService] Fetched user from API: @\(userResponse.zunoTag)")

            // Save or update user in local database
            let localUser = try await saveUser(userResponse)

            // Update auth state
            self.currentUser = localUser
            self.isAuthenticated = true
            
            print("✅ [AuthService] Quick login successful")
            return localUser
        } catch {
            print("❌ [AuthService] Failed to fetch user from API: \(error)")
            // Token might be expired - clear credentials
            throw AuthError.tokenExpired
        }
    }
    
    /// Quick login with biometrics (performs biometric auth + loads user)
    func quickLoginWithBiometrics() async throws -> LocalUser {
        // Check if biometric authentication is available
        guard biometricService.biometricsAvailable else {
            throw AuthError.biometricsNotAvailable
        }

        // Authenticate with biometrics
        let authenticated = try await biometricService.authenticate()
        guard authenticated else {
            throw AuthError.biometricAuthenticationFailed
        }

        // Now load the user
        return try await quickLogin()
    }

    // MARK: - Logout

    /// Logout the current user
    func logout() async {
        print("🔐 [AuthService] Logging out user")
        
        // Clear ALL authentication data from keychain
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.accessToken)
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.refreshToken)
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.userID)
        try? KeychainManager.shared.delete(forKey: Config.KeychainKeys.zunoTag)
        
        print("✓ [AuthService] Cleared all keychain data")

        // Update auth state
        self.currentUser = nil
        self.isAuthenticated = false
        
        print("✓ [AuthService] Logout complete")
    }

    // MARK: - User Profile Management

    /// Update current user profile
    func updateProfile(
        email: String? = nil,
        displayName: String? = nil,
        defaultCurrency: String? = nil,
        preferredNetwork: String? = nil,
        preferredStablecoin: String? = nil
    ) async throws -> LocalUser {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        // Update profile via API
        let updatedUser = try await APIClient.shared.updateUser(
            email: email,
            displayName: displayName,
            defaultCurrency: defaultCurrency,
            preferredNetwork: preferredNetwork,
            preferredStablecoin: preferredStablecoin
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
            existingUser.preferredStablecoin = userResponse.preferredStablecoin ?? "USDC"
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
