import Foundation

/// Application configuration
enum Config {
    /// API base URL
    static let apiBaseURL = "http://localhost:8080"

    /// API endpoints
    enum Endpoints {
        static let register = "/auth/register"
        static let registerComplete = "/auth/register/complete"
        static let login = "/auth/login"
        static let loginComplete = "/auth/login/complete"
        static let userProfile = "/users/me"
        static let wallets = "/wallets"
        static let transactions = "/transactions"
        static let sendTransaction = "/transactions/send"
        static func zunoTagLookup(_ tag: String) -> String { "/zuno/\(tag)" }
    }

    /// Keychain keys
    enum KeychainKeys {
        static let accessToken = "com.zuno.accessToken"
        static let refreshToken = "com.zuno.refreshToken"
        static let userID = "com.zuno.userID"
        static let zunoTag = "com.zuno.zunoTag"
    }

    /// WebAuthn configuration
    enum WebAuthn {
        static let relyingPartyID = "localhost"
        static let timeout: TimeInterval = 60
    }

    /// App configuration
    enum App {
        static let defaultCurrency = "USDC"
        static let defaultNetwork = "ARC-TESTNET"
        static let supportedNetworks = ["ARC-TESTNET", "MATIC-AMOY", "ARB-SEPOLIA"]
    }
}
