import Foundation
import AuthenticationServices

/// Service for passkey (WebAuthn) registration and authentication
@MainActor
final class PasskeyAuthService: NSObject {
    static let shared = PasskeyAuthService()

    private var authenticationAnchor: ASPresentationAnchor?
    private var registrationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>?
    private var authenticationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?

    private override init() {
        super.init()
    }

    // MARK: - Registration Flow

    /// Start passkey registration flow
    /// - Parameters:
    ///   - zunoTag: The @zuno tag for the user
    ///   - displayName: User's display name
    ///   - email: Optional email address
    ///   - window: The window to present the authentication UI
    /// - Returns: AuthResponse with tokens and user data
    func register(zunoTag: String, displayName: String?, email: String? = nil, window: ASPresentationAnchor) async throws -> AuthResponse {
        self.authenticationAnchor = window
        print("🔐 [PasskeyAuth] Starting registration for zunoTag: \(zunoTag)")

        do {
            // Step 1: Get registration challenge from backend
            print("🔐 [PasskeyAuth] Step 1: Requesting challenge from backend...")
            let challengeResponse: RegisterResponse = try await APIClient.shared.register(
                zunoTag: zunoTag,
                displayName: displayName,
                email: email
            )
            print("🔐 [PasskeyAuth] ✓ Received challenge response: challengeId=\(challengeResponse.challengeId)")
            print("🔐 [PasskeyAuth] Options keys: \(challengeResponse.options.keys)")

            // Step 2: Convert challenge options to platform credential request
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: Config.WebAuthn.relyingPartyID
            )

            // Parse challenge data
            let challengeString = extractBase64Challenge(from: challengeResponse.options)
            print("🔐 [PasskeyAuth] Extracted challenge string: \(challengeString.isEmpty ? "EMPTY" : challengeString.prefix(20))...")

            guard let challengeData = Data(base64Encoded: challengeString) else {
                print("🔐 [PasskeyAuth] ❌ Failed to decode challenge from base64")
                throw PasskeyError.invalidChallenge
            }
            print("🔐 [PasskeyAuth] ✓ Challenge data decoded: \(challengeData.count) bytes")

            let userIDData = extractUserID(from: challengeResponse.options)
            print("🔐 [PasskeyAuth] Extracted userID data: \(userIDData.isEmpty ? "EMPTY" : "\(userIDData.count) bytes")")

            let registrationRequest = platformProvider.createCredentialRegistrationRequest(
                challenge: challengeData,
                name: zunoTag,
                userID: userIDData
            )
            print("🔐 [PasskeyAuth] ✓ Created registration request")

            // Step 3: Present registration UI and get credential
            print("🔐 [PasskeyAuth] Step 3: Presenting passkey registration UI...")
            let credential = try await performRegistration(request: registrationRequest)
            print("🔐 [PasskeyAuth] ✓ Received credential from user")

            // Step 4: Send credential to backend to complete registration
            print("🔐 [PasskeyAuth] Step 4: Completing registration with backend...")
            let authResponse: AuthResponse = try await completeRegistration(
                challengeId: challengeResponse.challengeId,
                credential: credential
            )
            print("🔐 [PasskeyAuth] ✓ Registration completed successfully")

            // Step 5: Store tokens in keychain
            print("🔐 [PasskeyAuth] Step 5: Storing tokens in keychain...")
            try KeychainManager.shared.save(authResponse.accessToken, forKey: Config.KeychainKeys.accessToken)
            try KeychainManager.shared.save(authResponse.refreshToken, forKey: Config.KeychainKeys.refreshToken)
            print("🔐 [PasskeyAuth] ✓ Tokens stored successfully")

            return authResponse
            
        } catch let error as PasskeyError {
            // Already a PasskeyError, just rethrow
            print("🔐 [PasskeyAuth] ❌ PasskeyError: \(error.localizedDescription)")
            throw error
            
        } catch let error as NetworkError {
            // Convert NetworkError to PasskeyError
            print("🔐 [PasskeyAuth] ❌ NetworkError: \(error.localizedDescription)")
            switch error {
            case .noConnection, .timeout:
                throw PasskeyError.networkError(error.localizedDescription)
            case .httpError(409):
                // User already exists - suggest login instead
                throw PasskeyError.userAlreadyExists
            case .httpError(let code):
                throw PasskeyError.serverError(code)
            case .apiError(let apiError):
                throw PasskeyError.registrationFailed(apiError.message)
            default:
                throw PasskeyError.registrationFailed(error.localizedDescription)
            }
            
        } catch {
            // Unknown error
            print("🔐 [PasskeyAuth] ❌ Unknown error: \(error.localizedDescription)")
            throw PasskeyError.unknownError(error.localizedDescription)
        }
    }

    /// Perform passkey registration with ASAuthorizationController
    private func performRegistration(request: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        print("🔐 [PasskeyAuth] performRegistration: Creating ASAuthorizationController...")
        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation

            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            print("🔐 [PasskeyAuth] performRegistration: Calling performRequests()...")
            authController.performRequests()
        }
    }

    /// Complete registration by sending credential to backend
    private func completeRegistration(
        challengeId: String,
        credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
    ) async throws -> AuthResponse {
        // Convert credential to WebAuthn standard format (exactly as webauthn-rs expects)
        let credentialDict: [String: Any] = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "response": [
                "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                "attestationObject": credential.rawAttestationObject?.base64URLEncodedString() ?? "",
                "transports": [] // Optional but expected by some parsers
            ] as [String : Any],
            "type": "public-key",
            "clientExtensionResults": [:] as [String: Any] // Required by WebAuthn spec
        ]
        
        let request: [String: Any] = [
            "challenge_id": challengeId,
            "credential": credentialDict
        ]
        
        // Debug: print what we're sending
        if let jsonData = try? JSONSerialization.data(withJSONObject: request, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔐 [PasskeyAuth] Sending to backend:")
            print(jsonString)
        }

        return try await APIClient.shared.post(
            Config.Endpoints.registerComplete,
            body: request,
            authenticated: false
        )
    }

    // MARK: - Authentication Flow

    /// Start passkey authentication flow
    /// - Parameters:
    ///   - zunoTag: The @zuno tag to authenticate
    ///   - window: The window to present the authentication UI
    /// - Returns: AuthResponse with tokens and user data
    func authenticate(zunoTag: String, window: ASPresentationAnchor) async throws -> AuthResponse {
        self.authenticationAnchor = window

        // Step 1: Get authentication challenge from backend
        let challengeResponse: AuthenticationChallengeResponse = try await APIClient.shared.post(
            Config.Endpoints.login,
            body: LoginRequest(zunoTag: zunoTag),
            authenticated: false
        )

        // Step 2: Convert challenge to platform credential assertion request
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: Config.WebAuthn.relyingPartyID
        )

        guard let challengeData = Data(base64Encoded: extractBase64Challenge(from: challengeResponse.options)) else {
            throw PasskeyError.invalidChallenge
        }

        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)

        // Step 3: Present authentication UI and get assertion
        let assertion = try await performAuthentication(request: assertionRequest)

        // Step 4: Send assertion to backend to complete authentication
        let authResponse: AuthResponse = try await completeAuthentication(
            challengeId: challengeResponse.challengeId,
            assertion: assertion
        )

        // Step 5: Store tokens in keychain
        try KeychainManager.shared.save(authResponse.accessToken, forKey: Config.KeychainKeys.accessToken)
        try KeychainManager.shared.save(authResponse.refreshToken, forKey: Config.KeychainKeys.refreshToken)

        return authResponse
    }

    /// Perform passkey authentication with ASAuthorizationController
    private func performAuthentication(request: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        return try await withCheckedThrowingContinuation { continuation in
            self.authenticationContinuation = continuation

            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
    }

    /// Complete authentication by sending assertion to backend
    private func completeAuthentication(
        challengeId: String,
        assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion
    ) async throws -> AuthResponse {
        let request = CompleteLoginRequest(
            challengeId: challengeId,
            credential: CredentialAssertion(
                id: assertion.credentialID.base64URLEncodedString(),
                rawId: assertion.credentialID.base64URLEncodedString(),
                response: AuthenticatorAssertionResponse(
                    clientDataJSON: assertion.rawClientDataJSON.base64URLEncodedString(),
                    authenticatorData: assertion.rawAuthenticatorData.base64URLEncodedString(),
                    signature: assertion.signature.base64URLEncodedString(),
                    userHandle: assertion.userID.isEmpty ? nil : assertion.userID.base64URLEncodedString()
                ),
                type: "public-key"
            )
        )
        
        // Debug: print what we're sending
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔐 [PasskeyAuth] Sending login completion to backend:")
            print(jsonString)
        }

        return try await APIClient.shared.post(
            Config.Endpoints.loginComplete,
            body: request,
            authenticated: false
        )
    }

    // MARK: - Helper Methods

    /// Convert base64url to standard base64
    private func base64UrlToBase64(_ base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return base64
    }

    /// Extract base64 challenge from options dictionary
    private func extractBase64Challenge(from options: [String: AnyCodable]) -> String {
        print("🔐 [PasskeyAuth] extractBase64Challenge: Looking for publicKey.challenge...")
        guard let publicKey = options["publicKey"]?.value as? [String: Any] else {
            print("🔐 [PasskeyAuth] extractBase64Challenge: ❌ No publicKey found in options")
            return ""
        }
        print("🔐 [PasskeyAuth] extractBase64Challenge: publicKey keys: \(publicKey.keys)")
        guard let challenge = publicKey["challenge"] as? String else {
            print("🔐 [PasskeyAuth] extractBase64Challenge: ❌ No challenge found in publicKey")
            return ""
        }
        print("🔐 [PasskeyAuth] extractBase64Challenge: ✓ Found challenge (base64url)")
        // Convert base64url to base64
        let base64Challenge = base64UrlToBase64(challenge)
        print("🔐 [PasskeyAuth] extractBase64Challenge: Converted to standard base64")
        return base64Challenge
    }

    /// Extract user ID from options dictionary
    private func extractUserID(from options: [String: AnyCodable]) -> Data {
        print("🔐 [PasskeyAuth] extractUserID: Looking for publicKey.user.id...")
        guard let publicKey = options["publicKey"]?.value as? [String: Any] else {
            print("🔐 [PasskeyAuth] extractUserID: ❌ No publicKey found in options")
            return Data()
        }
        guard let user = publicKey["user"] as? [String: Any] else {
            print("🔐 [PasskeyAuth] extractUserID: ❌ No user found in publicKey")
            return Data()
        }
        print("🔐 [PasskeyAuth] extractUserID: user keys: \(user.keys)")
        guard let idString = user["id"] as? String else {
            print("🔐 [PasskeyAuth] extractUserID: ❌ No id found in user")
            return Data()
        }
        print("🔐 [PasskeyAuth] extractUserID: ✓ Found user ID (base64url)")
        // Convert base64url to base64
        let base64Id = base64UrlToBase64(idString)
        guard let idData = Data(base64Encoded: base64Id) else {
            print("🔐 [PasskeyAuth] extractUserID: ❌ Failed to decode id from base64")
            return Data()
        }
        print("🔐 [PasskeyAuth] extractUserID: ✓ Decoded user ID successfully")
        return idData
    }
}

// MARK: - Data Extension for Base64URL Encoding

extension Data {
    /// Encode data as base64url (URL-safe base64 without padding)
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🔐 [PasskeyAuth] Delegate: didCompleteWithAuthorization called")
        switch authorization.credential {
        case let credential as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            print("🔐 [PasskeyAuth] Delegate: Received registration credential")
            registrationContinuation?.resume(returning: credential)
            registrationContinuation = nil

        case let credential as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            print("🔐 [PasskeyAuth] Delegate: Received authentication credential")
            authenticationContinuation?.resume(returning: credential)
            authenticationContinuation = nil

        default:
            print("🔐 [PasskeyAuth] Delegate: ❌ Unsupported credential type")
            registrationContinuation?.resume(throwing: PasskeyError.unsupportedCredentialType)
            authenticationContinuation?.resume(throwing: PasskeyError.unsupportedCredentialType)
            registrationContinuation = nil
            authenticationContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🔐 [PasskeyAuth] Delegate: ❌ didCompleteWithError: \(error.localizedDescription)")
        print("🔐 [PasskeyAuth] Delegate: Error details: \(error)")
        
        // Convert to PasskeyError for better error messages
        let passkeyError = PasskeyError.from(authError: error)
        print("🔐 [PasskeyAuth] Delegate: Converted to: \(passkeyError.localizedDescription)")
        
        registrationContinuation?.resume(throwing: passkeyError)
        authenticationContinuation?.resume(throwing: passkeyError)
        registrationContinuation = nil
        authenticationContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🔐 [PasskeyAuth] presentationAnchor called")
        // Return stored anchor or get the main window
        if let anchor = authenticationAnchor {
            print("🔐 [PasskeyAuth] Using stored anchor")
            return anchor
        }

        // Fallback: get the first window from connected scenes
        print("🔐 [PasskeyAuth] Using fallback window from connected scenes")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("🔐 [PasskeyAuth] ❌ No window available for passkey presentation")
            fatalError("No window available for passkey presentation")
        }

        return window
    }
}

// MARK: - Additional Models for WebAuthn

struct CompleteRegisterRequest: Codable {
    let challengeId: String
    let credential: CredentialRegistration

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case credential
    }
}

struct CredentialRegistration: Codable {
    let id: String
    let rawId: String
    let response: AuthenticatorAttestationResponse
    let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case rawId = "raw_id"
        case response
        case type
    }
}

struct AuthenticatorAttestationResponse: Codable {
    let clientDataJSON: String
    let attestationObject: String

    enum CodingKeys: String, CodingKey {
        case clientDataJSON = "client_data_json"
        case attestationObject = "attestation_object"
    }
}

struct LoginRequest: Codable {
    let zunoTag: String

    enum CodingKeys: String, CodingKey {
        case zunoTag = "zuno_tag"
    }
}

struct AuthenticationChallengeResponse: Codable {
    let challengeId: String
    let options: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case options
    }
}

struct CompleteLoginRequest: Codable {
    let challengeId: String
    let credential: CredentialAssertion

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"  // Backend expects snake_case
        case credential
    }
}

struct CredentialAssertion: Codable {
    let id: String
    let rawId: String
    let response: AuthenticatorAssertionResponse
    let type: String
    let clientExtensionResults: [String: String]
    
    init(id: String, rawId: String, response: AuthenticatorAssertionResponse, type: String) {
        self.id = id
        self.rawId = rawId
        self.response = response
        self.type = type
        self.clientExtensionResults = [:]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case rawId
        case response
        case type
        case clientExtensionResults
    }
}

struct AuthenticatorAssertionResponse: Codable {
    let clientDataJSON: String
    let authenticatorData: String
    let signature: String
    let userHandle: String?

    enum CodingKeys: String, CodingKey {
        case clientDataJSON
        case authenticatorData
        case signature
        case userHandle
    }
}

// MARK: - Errors

enum PasskeyError: LocalizedError {
    case invalidChallenge
    case unsupportedCredentialType
    case registrationFailed(String)
    case authenticationFailed(String)
    case userCanceled
    case biometricFailed
    case networkError(String)
    case serverError(Int)
    case userAlreadyExists
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .invalidChallenge:
            return "Invalid challenge received from server"
        case .unsupportedCredentialType:
            return "Unsupported credential type"
        case .registrationFailed(let reason):
            return "Registration failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .userCanceled:
            return "Authentication was canceled"
        case .biometricFailed:
            return "Biometric authentication failed. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .userAlreadyExists:
            return "This @zuno tag is already registered"
        case .unknownError(let message):
            return "An error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .userCanceled:
            return "Tap 'Register Passkey' to try again"
        case .biometricFailed:
            return "Make sure Face ID/Touch ID is enabled in Settings"
        case .networkError:
            return "Check your internet connection and try again"
        case .serverError:
            return "The server is experiencing issues. Please try again in a few moments."
        case .invalidChallenge:
            return "Please try registering again"
        case .userAlreadyExists:
            return "This account already exists. Please use the Login button to sign in with your passkey."
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    /// Convert ASAuthorization error to PasskeyError
    static func from(authError: Error) -> PasskeyError {
        let nsError = authError as NSError
        
        // ASAuthorizationError codes
        switch nsError.code {
        case 1001: // ASAuthorizationError.canceled
            return .userCanceled
        case 1004: // ASAuthorizationError.failed
            return .biometricFailed
        case 1000: // ASAuthorizationError.unknown
            return .unknownError("Authentication system error")
        default:
            return .unknownError(authError.localizedDescription)
        }
    }
}
