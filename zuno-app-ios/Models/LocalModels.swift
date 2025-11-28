import Foundation
import SwiftData

// MARK: - User Model

@Model
final class LocalUser {
    @Attribute(.unique) var id: String
    var zunoTag: String
    var email: String?
    var displayName: String?
    var defaultCurrency: String
    var preferredNetwork: String
    var preferredStablecoin: String
    var isVerified: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LocalWallet.user)
    var wallets: [LocalWallet]

    init(
        id: String,
        zunoTag: String,
        email: String? = nil,
        displayName: String? = nil,
        defaultCurrency: String = Config.App.defaultCurrency,
        preferredNetwork: String = Config.App.defaultNetwork,
        preferredStablecoin: String = "USDC",
        isVerified: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.zunoTag = zunoTag
        self.email = email
        self.displayName = displayName
        self.defaultCurrency = defaultCurrency
        self.preferredNetwork = preferredNetwork
        self.preferredStablecoin = preferredStablecoin
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.wallets = []
    }

    /// Create LocalUser from API response
    static func from(_ response: UserResponse) -> LocalUser {
        return LocalUser(
            id: response.id,
            zunoTag: response.zunoTag,
            email: response.email,
            displayName: response.displayName,
            defaultCurrency: response.defaultCurrency ?? Config.App.defaultCurrency,
            preferredNetwork: response.preferredNetwork ?? Config.App.defaultNetwork,
            preferredStablecoin: response.preferredStablecoin ?? "USDC",
            isVerified: response.isVerified,
            createdAt: response.createdAt,
            updatedAt: Date()
        )
    }
}

// MARK: - Wallet Model

@Model
final class LocalWallet {
    @Attribute(.unique) var id: String
    var walletAddress: String
    var blockchain: String
    var accountType: String
    var isPrimary: Bool
    var name: String?
    var balance: String?
    var balanceUSD: Double?
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var userId: String  // Added for predicate queries

    var user: LocalUser?

    @Relationship(deleteRule: .cascade, inverse: \LocalTransaction.wallet)
    var transactions: [LocalTransaction]

    init(
        id: String,
        walletAddress: String,
        blockchain: String,
        accountType: String,
        userId: String = "",
        isPrimary: Bool = false,
        name: String? = nil,
        balance: String? = nil,
        balanceUSD: Double? = nil,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.walletAddress = walletAddress
        self.blockchain = blockchain
        self.accountType = accountType
        self.userId = userId
        self.isPrimary = isPrimary
        self.name = name
        self.balance = balance
        self.balanceUSD = balanceUSD
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transactions = []
    }

    /// Create LocalWallet from API response
    static func from(_ response: WalletResponse, userId: String = "") -> LocalWallet {
        return LocalWallet(
            id: response.id,
            walletAddress: response.walletAddress,
            blockchain: response.blockchain,
            accountType: response.accountType,
            userId: userId,
            isPrimary: response.isPrimary,
            balance: response.balance ?? "0",  // Default to "0" if no balance
            balanceUSD: Double(response.balance ?? "0") ?? 0.0,
            createdAt: response.createdAt,
            updatedAt: Date()
        )
    }

    /// Formatted blockchain name for display
    var blockchainDisplayName: String {
        switch blockchain {
        case "ARC-TESTNET": return "Arc Testnet"
        case "MATIC-AMOY": return "Polygon Amoy"
        case "ARB-SEPOLIA": return "Arbitrum Sepolia"
        case "ETH-SEPOLIA": return "Ethereum Sepolia"
        case "AVAX-FUJI": return "Avalanche Fuji"
        case "SOL-DEVNET": return "Solana Devnet"
        default: return blockchain
        }
    }

    /// Formatted wallet address (shortened)
    var shortAddress: String {
        guard walletAddress.count > 10 else { return walletAddress }
        let prefix = walletAddress.prefix(6)
        let suffix = walletAddress.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    /// Token symbol for this blockchain
    var tokenSymbol: String {
        if blockchain.contains("USDC") {
            return "USDC"
        }
        switch blockchain.uppercased() {
        case let chain where chain.contains("ARC"):
            return "ARC"
        case let chain where chain.contains("ETH"):
            return "ETH"
        case let chain where chain.contains("MATIC") || chain.contains("POLYGON"):
            return "MATIC"
        case let chain where chain.contains("ARB"):
            return "ETH"
        case let chain where chain.contains("AVAX"):
            return "AVAX"
        case let chain where chain.contains("SOL"):
            return "SOL"
        default:
            return "USDC"
        }
    }
}

// MARK: - Transaction Model

@Model
final class LocalTransaction {
    @Attribute(.unique) var id: String
    var transactionType: TransactionType
    var status: TransactionStatus
    var amount: String
    var tokenSymbol: String
    var blockchain: String?
    var fromAddress: String?
    var toAddress: String?
    var toZunoTag: String?
    var blockchainTxHash: String?
    var txDescription: String?
    var fee: String?
    var confirmations: Int?
    var createdAt: Date
    var updatedAt: Date
    var walletId: String  // Added for predicate queries

    var wallet: LocalWallet?

    init(
        id: String,
        transactionType: TransactionType,
        status: TransactionStatus,
        amount: String,
        tokenSymbol: String,
        blockchain: String? = nil,
        walletId: String = "",
        fromAddress: String? = nil,
        toAddress: String? = nil,
        toZunoTag: String? = nil,
        blockchainTxHash: String? = nil,
        txDescription: String? = nil,
        fee: String? = nil,
        confirmations: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.transactionType = transactionType
        self.status = status
        self.amount = amount
        self.tokenSymbol = tokenSymbol
        self.blockchain = blockchain
        self.walletId = walletId
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.toZunoTag = toZunoTag
        self.blockchainTxHash = blockchainTxHash
        self.txDescription = txDescription
        self.fee = fee
        self.confirmations = confirmations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create LocalTransaction from API response
    /// Uses walletId from API response by default, with optional override
    static func from(_ response: TransactionResponse, walletId: String? = nil) -> LocalTransaction {
        return LocalTransaction(
            id: response.id,
            transactionType: TransactionType(rawValue: response.transactionType) ?? .send,
            status: TransactionStatus(rawValue: response.status) ?? .pending,
            amount: response.amount,
            tokenSymbol: response.tokenSymbol,
            walletId: walletId ?? response.walletId,
            fromAddress: response.fromAddress,
            toAddress: response.toAddress,
            toZunoTag: response.toZunoTag,
            blockchainTxHash: response.blockchainTxHash,
            createdAt: response.createdAt,
            updatedAt: Date()
        )
    }

    /// Formatted amount with symbol
    var formattedAmount: String {
        return "\(amount) \(tokenSymbol)"
    }

    /// Is transaction incoming (received)
    var isIncoming: Bool {
        return transactionType == .receive
    }

    /// Is transaction outgoing (sent)
    var isOutgoing: Bool {
        return transactionType == .send
    }

    /// Transaction status icon
    var statusIcon: String {
        switch status {
        case .pending: return "clock"
        case .confirming: return "arrow.triangle.2.circlepath"
        case .confirmed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    /// Transaction status color
    var statusColor: String {
        switch status {
        case .pending: return "yellow"
        case .confirming: return "orange"
        case .confirmed: return "green"
        case .failed, .cancelled: return "red"
        }
    }

    /// Formatted recipient (address or @zuno tag)
    var recipientDisplay: String {
        if let zunoTag = toZunoTag {
            return "@\(zunoTag)"
        } else if let address = toAddress {
            return address.count > 10 ? "\(address.prefix(6))...\(address.suffix(4))" : address
        }
        return "Unknown"
    }
}

// MARK: - Enums

enum TransactionType: String, Codable {
    case send = "send"
    case receive = "receive"
    case swap = "swap"
    case tapToPay = "tap_to_pay"
    case contractInteraction = "contract_interaction"

    var displayName: String {
        switch self {
        case .send: return "Sent"
        case .receive: return "Received"
        case .swap: return "Swapped"
        case .tapToPay: return "Tap to Pay"
        case .contractInteraction: return "Contract"
        }
    }

    var icon: String {
        switch self {
        case .send: return "arrow.up.right"
        case .receive: return "arrow.down.left"
        case .swap: return "arrow.left.arrow.right"
        case .tapToPay: return "wave.3.right"
        case .contractInteraction: return "doc.text"
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case confirming = "confirming"
    case confirmed = "confirmed"
    case failed = "failed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .confirming: return "Confirming"
        default: return rawValue.capitalized
        }
    }
}

// MARK: - Cache Model for Offline Support

@Model
final class CachedData {
    @Attribute(.unique) var key: String
    var value: Data
    var expiresAt: Date
    var createdAt: Date

    init(key: String, value: Data, expiresAt: Date, createdAt: Date = Date()) {
        self.key = key
        self.value = value
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    /// Check if cache is expired
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// MARK: - App Settings Model

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var isDarkMode: Bool
    var biometricEnabled: Bool
    var notificationsEnabled: Bool
    var analyticsEnabled: Bool
    var defaultCurrency: String
    var preferredNetwork: String
    var language: String
    var updatedAt: Date

    init(
        id: String = "default",
        isDarkMode: Bool = true,
        biometricEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        analyticsEnabled: Bool = false,
        defaultCurrency: String = Config.App.defaultCurrency,
        preferredNetwork: String = Config.App.defaultNetwork,
        language: String = "en",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.isDarkMode = isDarkMode
        self.biometricEnabled = biometricEnabled
        self.notificationsEnabled = notificationsEnabled
        self.analyticsEnabled = analyticsEnabled
        self.defaultCurrency = defaultCurrency
        self.preferredNetwork = preferredNetwork
        self.language = language
        self.updatedAt = updatedAt
    }
}

// MARK: - ModelContainer Preview Extension

extension ModelContainer {
    static var preview: ModelContainer {
        let schema = Schema([
            LocalUser.self,
            LocalWallet.self,
            LocalTransaction.self,
            CachedData.self,
            AppSettings.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Add sample data for preview
            let context = container.mainContext
            
            let sampleUser = LocalUser(
                id: "preview-user-1",
                zunoTag: "preview",
                displayName: "Preview User"
            )
            context.insert(sampleUser)
            
            let sampleWallet = LocalWallet(
                id: "preview-wallet-1",
                walletAddress: "0x1234567890abcdef1234567890abcdef12345678",
                blockchain: "ARC-TESTNET",
                accountType: "EOA",
                userId: sampleUser.id,
                isPrimary: true,
                balance: "100.00",
                balanceUSD: 100.00
            )
            sampleWallet.user = sampleUser
            context.insert(sampleWallet)
            
            try? context.save()
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
