import Foundation
import AuthenticationServices

/// Service for passkey (WebAuthn) registration and authentication
@MainActor
final class PasskeyAuthService: NSObject, ObservableObject {
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
    ///   - window: The window to present the authentication UI
    /// - Returns: AuthResponse with tokens and user data
    func register(zunoTag: String, displayName: String?, window: ASPresentationAnchor) async throws -> AuthResponse {
        self.authenticationAnchor = window

        // Step 1: Get registration challenge from backend
        let challengeResponse: RegisterResponse = try await APIClient.shared.register(
            zunoTag: zunoTag,
            displayName: displayName
        )

        // Step 2: Convert challenge options to platform credential request
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: Config.WebAuthn.relyingPartyID
        )

        // Parse challenge data
        guard let challengeData = Data(base64Encoded: extractBase64Challenge(from: challengeResponse.options)) else {
            throw PasskeyError.invalidChallenge
        }

        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: zunoTag,
            userID: extractUserID(from: challengeResponse.options)
        )

        // Step 3: Present registration UI and get credential
        let credential = try await performRegistration(request: registrationRequest)

        // Step 4: Send credential to backend to complete registration
        let authResponse: AuthResponse = try await completeRegistration(
            challengeId: challengeResponse.challengeId,
            credential: credential
        )

        // Step 5: Store tokens in keychain
        try KeychainManager.shared.save(authResponse.accessToken, forKey: Config.KeychainKeys.accessToken)
        try KeychainManager.shared.save(authResponse.refreshToken, forKey: Config.KeychainKeys.refreshToken)

        return authResponse
    }

    /// Perform passkey registration with ASAuthorizationController
    private func performRegistration(request: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation

            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
    }

    /// Complete registration by sending credential to backend
    private func completeRegistration(
        challengeId: String,
        credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
    ) async throws -> AuthResponse {
        let request = CompleteRegisterRequest(
            challengeId: challengeId,
            credential: CredentialRegistration(
                id: credential.credentialID.base64EncodedString(),
                rawId: credential.credentialID.base64EncodedString(),
                response: AuthenticatorAttestationResponse(
                    clientDataJSON: credential.rawClientDataJSON.base64EncodedString(),
                    attestationObject: credential.rawAttestationObject?.base64EncodedString() ?? ""
                ),
                type: "public-key"
            )
        )

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
                id: assertion.credentialID.base64EncodedString(),
                rawId: assertion.credentialID.base64EncodedString(),
                response: AuthenticatorAssertionResponse(
                    clientDataJSON: assertion.rawClientDataJSON.base64EncodedString(),
                    authenticatorData: assertion.rawAuthenticatorData.base64EncodedString(),
                    signature: assertion.signature.base64EncodedString(),
                    userHandle: assertion.userID.base64EncodedString()
                ),
                type: "public-key"
            )
        )

        return try await APIClient.shared.post(
            Config.Endpoints.loginComplete,
            body: request,
            authenticated: false
        )
    }

    // MARK: - Helper Methods

    /// Extract base64 challenge from options dictionary
    private func extractBase64Challenge(from options: [String: AnyCodable]) -> String {
        guard let challenge = options["challenge"]?.value as? String else {
            return ""
        }
        return challenge
    }

    /// Extract user ID from options dictionary
    private func extractUserID(from options: [String: AnyCodable]) -> Data {
        guard let user = options["user"]?.value as? [String: Any],
              let idString = user["id"] as? String,
              let idData = Data(base64Encoded: idString) else {
            return Data()
        }
        return idData
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let credential as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            registrationContinuation?.resume(returning: credential)
            registrationContinuation = nil

        case let credential as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            authenticationContinuation?.resume(returning: credential)
            authenticationContinuation = nil

        default:
            registrationContinuation?.resume(throwing: PasskeyError.unsupportedCredentialType)
            authenticationContinuation?.resume(throwing: PasskeyError.unsupportedCredentialType)
            registrationContinuation = nil
            authenticationContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        registrationContinuation?.resume(throwing: error)
        authenticationContinuation?.resume(throwing: error)
        registrationContinuation = nil
        authenticationContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor ?? ASPresentationAnchor()
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
        case challengeId = "challenge_id"
        case credential
    }
}

struct CredentialAssertion: Codable {
    let id: String
    let rawId: String
    let response: AuthenticatorAssertionResponse
    let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case rawId = "raw_id"
        case response
        case type
    }
}

struct AuthenticatorAssertionResponse: Codable {
    let clientDataJSON: String
    let authenticatorData: String
    let signature: String
    let userHandle: String

    enum CodingKeys: String, CodingKey {
        case clientDataJSON = "client_data_json"
        case authenticatorData = "authenticator_data"
        case signature
        case userHandle = "user_handle"
    }
}

// MARK: - Errors

enum PasskeyError: LocalizedError {
    case invalidChallenge
    case unsupportedCredentialType
    case registrationFailed(String)
    case authenticationFailed(String)

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
        }
    }
}
