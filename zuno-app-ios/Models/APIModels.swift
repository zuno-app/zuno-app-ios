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
    let preferredStablecoin: String?
    let isVerified: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case zunoTag = "zuno_tag"
        case email
        case displayName = "display_name"
        case defaultCurrency = "default_currency"
        case preferredNetwork = "preferred_network"
        case preferredStablecoin = "preferred_stablecoin"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }
}

struct UpdateUserRequest: Codable {
    let email: String?
    let displayName: String?
    let defaultCurrency: String?
    let preferredNetwork: String?
    let preferredStablecoin: String?

    enum CodingKeys: String, CodingKey {
        case email
        case displayName = "display_name"
        case defaultCurrency = "default_currency"
        case preferredNetwork = "preferred_network"
        case preferredStablecoin = "preferred_stablecoin"
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
    let balance: String?
    let tokenSymbol: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case walletAddress = "wallet_address"
        case blockchain
        case accountType = "account_type"
        case isPrimary = "is_primary"
        case balance
        case tokenSymbol = "token_symbol"
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
    let category: String?

    enum CodingKeys: String, CodingKey {
        case toAddress = "to_address"
        case toZunoTag = "to_zuno_tag"
        case amount
        case tokenSymbol = "token_symbol"
        case blockchain
        case description
        case category
    }
}

struct TransactionResponse: Codable, Identifiable {
    let id: String
    let walletId: String
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
        case walletId = "wallet_id"
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

struct ZunoTagAvailabilityResponse: Codable {
    let available: Bool
    let zunoTag: String

    enum CodingKeys: String, CodingKey {
        case available
        case zunoTag = "zuno_tag"
    }
}

struct EmailAvailabilityResponse: Codable {
    let available: Bool
    let email: String
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


// MARK: - Balance Aggregation Models

struct TokenBalanceInfo: Codable, Identifiable {
    var id: String { "\(walletId)_\(tokenSymbol)" }
    
    let tokenSymbol: String
    let amount: Double
    let blockchain: String
    let walletAddress: String
    let walletId: String
    let valueUsd: Double
    let valueEur: Double
    let valueGbp: Double
    let valueUsdc: Double
    let valueEurc: Double
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case amount
        case blockchain
        case walletAddress = "wallet_address"
        case walletId = "wallet_id"
        case valueUsd = "value_usd"
        case valueEur = "value_eur"
        case valueGbp = "value_gbp"
        case valueUsdc = "value_usdc"
        case valueEurc = "value_eurc"
        case lastUpdated = "last_updated"
    }
}

struct AggregatedBalanceResponse: Codable {
    let totalValueUsd: Double
    let totalValueEur: Double
    let totalValueGbp: Double
    let totalValueUsdc: Double
    let totalValueEurc: Double
    let preferredFiat: String
    let preferredStablecoin: String
    let totalInPreferredFiat: Double
    let totalInPreferredStablecoin: Double
    let tokenBreakdown: [TokenBalanceInfo]
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case totalValueUsd = "total_value_usd"
        case totalValueEur = "total_value_eur"
        case totalValueGbp = "total_value_gbp"
        case totalValueUsdc = "total_value_usdc"
        case totalValueEurc = "total_value_eurc"
        case preferredFiat = "preferred_fiat"
        case preferredStablecoin = "preferred_stablecoin"
        case totalInPreferredFiat = "total_in_preferred_fiat"
        case totalInPreferredStablecoin = "total_in_preferred_stablecoin"
        case tokenBreakdown = "token_breakdown"
        case lastUpdated = "last_updated"
    }
}

struct PriceConversionRequest: Codable {
    let amount: Double
    let fromCurrency: String
    let toCurrency: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case fromCurrency = "from_currency"
        case toCurrency = "to_currency"
    }
}

struct PriceConversionResponse: Codable {
    let fromCurrency: String
    let toCurrency: String
    let fromAmount: Double
    let toAmount: Double
    let exchangeRate: Double
    let usdEurRate: Double
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case fromCurrency = "from_currency"
        case toCurrency = "to_currency"
        case fromAmount = "from_amount"
        case toAmount = "to_amount"
        case exchangeRate = "exchange_rate"
        case usdEurRate = "usd_eur_rate"
        case timestamp
    }
}

struct ExchangeRatesResponse: Codable {
    let usdEurRate: Double
    let usdGbpRate: Double
    let eurUsdRate: Double
    let gbpUsdRate: Double
    let tokens: [String: TokenPriceInfo]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case usdEurRate = "usd_eur_rate"
        case usdGbpRate = "usd_gbp_rate"
        case eurUsdRate = "eur_usd_rate"
        case gbpUsdRate = "gbp_usd_rate"
        case tokens
        case lastUpdated = "last_updated"
    }
}

struct TokenPriceInfo: Codable {
    let priceUsd: Double
    let priceEur: Double
    let priceGbp: Double
    
    enum CodingKeys: String, CodingKey {
        case priceUsd = "price_usd"
        case priceEur = "price_eur"
        case priceGbp = "price_gbp"
    }
}
