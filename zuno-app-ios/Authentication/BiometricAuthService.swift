import LocalAuthentication
import Foundation

/// Service for biometric authentication (Face ID / Touch ID / Device Passcode)
final class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    /// Authenticate user with biometrics or device passcode
    func authenticate(reason: String = "Authenticate to access your wallet") async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch let laError as LAError {
            throw BiometricError.authenticationFailed(laError.localizedDescription)
        }
    }

    /// Check if biometrics are available
    var biometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Get biometric type (Face ID, Touch ID, or None)
    var biometricType: BiometricType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .passcode
        }
    }
}

enum BiometricType {
    case faceID
    case touchID
    case passcode
    case none

    var description: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .passcode: return "Device Passcode"
        case .none: return "None"
        }
    }

    var icon: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .passcode: return "lock.fill"
        case .none: return "xmark.circle"
        }
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        }
    }
}
