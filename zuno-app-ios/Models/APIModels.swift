import Foundation

// MARK: - Authentication Models

struct RegisterRequest: Codable {
    let zunoTag: String
    let email: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case zunoTag = "zuno_tag"
        case email
        case displayName = "display_name"
    }
}

struct RegisterResponse: Codable {
    let challengeId: String
    let options: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case options
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: UserResponse

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

// MARK: - User Models

struct UserResponse: Codable {
    let id: String
    let zunoTag: String
    let email: String?
    let displayName: String?
    let defaultCurrency: String?
    let preferredNetwork: String?
    let isVerified: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case zunoTag = "zuno_tag"
        case email
        case displayName = "display_name"
        case defaultCurrency = "default_currency"
        case preferredNetwork = "preferred_network"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }
}

struct UpdateUserRequest: Codable {
    let email: String?
    let displayName: String?
    let defaultCurrency: String?
    let preferredNetwork: String?

    enum CodingKeys: String, CodingKey {
        case email
        case displayName = "display_name"
        case defaultCurrency = "default_currency"
        case preferredNetwork = "preferred_network"
    }
}

// MARK: - Wallet Models

struct CreateWalletRequest: Codable {
    let blockchain: String
    let accountType: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case blockchain
        case accountType = "account_type"
        case name
    }
}

struct WalletResponse: Codable, Identifiable {
    let id: String
    let walletAddress: String
    let blockchain: String
    let accountType: String
    let isPrimary: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case walletAddress = "wallet_address"
        case blockchain
        case accountType = "account_type"
        case isPrimary = "is_primary"
        case createdAt = "created_at"
    }
}

// MARK: - Transaction Models

struct SendTransactionRequest: Codable {
    let toAddress: String?
    let toZunoTag: String?
    let amount: String
    let tokenSymbol: String
    let blockchain: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case toAddress = "to_address"
        case toZunoTag = "to_zuno_tag"
        case amount
        case tokenSymbol = "token_symbol"
        case blockchain
        case description
    }
}

struct TransactionResponse: Codable, Identifiable {
    let id: String
    let transactionType: String
    let status: String
    let amount: String
    let tokenSymbol: String
    let fromAddress: String?
    let toAddress: String?
    let toZunoTag: String?
    let blockchainTxHash: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transactionType = "transaction_type"
        case status
        case amount
        case tokenSymbol = "token_symbol"
        case fromAddress = "from_address"
        case toAddress = "to_address"
        case toZunoTag = "to_zuno_tag"
        case blockchainTxHash = "blockchain_tx_hash"
        case createdAt = "created_at"
    }
}

// MARK: - Zuno Tag Models

struct ZunoTagLookupResponse: Codable {
    let zunoTag: String
    let displayName: String?
    let primaryWalletAddress: String?

    enum CodingKeys: String, CodingKey {
        case zunoTag = "zuno_tag"
        case displayName = "display_name"
        case primaryWalletAddress = "primary_wallet_address"
    }
}

// MARK: - Error Models

struct APIError: Codable, LocalizedError {
    let error: String
    let message: String

    var errorDescription: String? { message }
}

// MARK: - Helper: AnyCodable for dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
