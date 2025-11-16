import Foundation
import SwiftData
import Combine

/// Service for wallet management
@MainActor
final class WalletService: ObservableObject {
    @Published var wallets: [LocalWallet] = []
    @Published var primaryWallet: LocalWallet?
    @Published var isLoading: Bool = false

    private let modelContext: ModelContext
    private var currentUser: LocalUser?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Set the current user and load their wallets
    func setCurrentUser(_ user: LocalUser) async {
        self.currentUser = user
        await loadWallets()
    }

    // MARK: - Wallet Management

    /// Load wallets from local database and sync with API
    func loadWallets(forceRefresh: Bool = false) async {
        guard let user = currentUser else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            if forceRefresh {
                // Fetch from API
                let walletResponses = try await APIClient.shared.listWallets()

                // Save to local database
                for response in walletResponses {
                    _ = try await saveWallet(response, for: user)
                }
            }

            // Load from local database
            let userId = user.id
            let descriptor = FetchDescriptor<LocalWallet>(
                predicate: #Predicate { $0.userId == userId }
            )
            let fetchedWallets = try modelContext.fetch(descriptor)

            // Sort in memory: primary first, then by creation date
            self.wallets = fetchedWallets.sorted { wallet1, wallet2 in
                if wallet1.isPrimary != wallet2.isPrimary {
                    return wallet1.isPrimary
                }
                return wallet1.createdAt < wallet2.createdAt
            }
            self.primaryWallet = wallets.first { $0.isPrimary }

        } catch {
            print("Error loading wallets: \(error)")
        }
    }

    /// Create a new wallet
    func createWallet(blockchain: String, name: String? = nil) async throws -> LocalWallet {
        guard let user = currentUser else {
            throw WalletError.noCurrentUser
        }

        isLoading = true
        defer { isLoading = false }

        // Create wallet via API
        let walletResponse = try await APIClient.shared.createWallet(blockchain: blockchain)

        // Save to local database
        let localWallet = try await saveWallet(walletResponse, for: user)

        // Update wallet name if provided
        if let name = name {
            localWallet.name = name
            localWallet.updatedAt = Date()
            try modelContext.save()
        }

        // Reload wallets
        await loadWallets()

        return localWallet
    }

    /// Get wallet balance
    func getBalance(for wallet: LocalWallet) async throws -> WalletBalance {
        guard wallet.id != "" else {
            throw WalletError.invalidWallet
        }

        // For now, return mock balance
        // TODO: Implement actual balance fetching from wallet service
        let balance = WalletBalance(
            amount: wallet.balance ?? "0",
            symbol: "USDC",
            amountUSD: wallet.balanceUSD ?? 0.0
        )

        // Update local cache
        wallet.balance = balance.amount
        wallet.balanceUSD = balance.amountUSD
        wallet.lastSyncedAt = Date()
        wallet.updatedAt = Date()
        try modelContext.save()

        return balance
    }

    /// Refresh balances for all wallets
    func refreshBalances() async {
        for wallet in wallets {
            do {
                _ = try await getBalance(for: wallet)
            } catch {
                print("Error refreshing balance for wallet \(wallet.id): \(error)")
            }
        }
    }

    /// Set primary wallet
    func setPrimaryWallet(_ wallet: LocalWallet) async throws {
        guard let user = currentUser else {
            throw WalletError.noCurrentUser
        }

        // Update all wallets for this user
        let userId = user.id
        let descriptor = FetchDescriptor<LocalWallet>(
            predicate: #Predicate { $0.userId == userId }
        )
        let allWallets = try modelContext.fetch(descriptor)

        for w in allWallets {
            w.isPrimary = (w.id == wallet.id)
            w.updatedAt = Date()
        }

        try modelContext.save()

        // Update published properties
        self.primaryWallet = wallet
        await loadWallets()
    }

    /// Delete wallet
    func deleteWallet(_ wallet: LocalWallet) async throws {
        guard !wallet.isPrimary else {
            throw WalletError.cannotDeletePrimaryWallet
        }

        modelContext.delete(wallet)
        try modelContext.save()

        await loadWallets()
    }

    // MARK: - Wallet Lookup

    /// Lookup wallet by @zuno tag
    func lookupWallet(byZunoTag tag: String) async throws -> ZunoTagLookupResponse {
        // Remove @ prefix if present
        let cleanTag = tag.hasPrefix("@") ? String(tag.dropFirst()) : tag

        return try await APIClient.shared.lookupZunoTag(cleanTag)
    }

    // MARK: - Helper Methods

    /// Save or update wallet in local database
    private func saveWallet(_ walletResponse: WalletResponse, for user: LocalUser) async throws -> LocalWallet {
        // Check if wallet already exists
        let descriptor = FetchDescriptor<LocalWallet>(
            predicate: #Predicate { $0.id == walletResponse.id }
        )
        let existingWallets = try modelContext.fetch(descriptor)

        if let existingWallet = existingWallets.first {
            // Update existing wallet
            existingWallet.walletAddress = walletResponse.walletAddress
            existingWallet.blockchain = walletResponse.blockchain
            existingWallet.accountType = walletResponse.accountType
            existingWallet.isPrimary = walletResponse.isPrimary
            existingWallet.userId = user.id
            existingWallet.updatedAt = Date()
            try modelContext.save()
            return existingWallet
        } else {
            // Create new wallet
            let newWallet = LocalWallet.from(walletResponse, userId: user.id)
            newWallet.user = user
            modelContext.insert(newWallet)
            try modelContext.save()
            return newWallet
        }
    }
}

// MARK: - Supporting Types

struct WalletBalance: Codable {
    let amount: String
    let symbol: String
    let amountUSD: Double

    var formattedAmount: String {
        return "\(amount) \(symbol)"
    }

    var formattedUSD: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amountUSD)) ?? "$0.00"
    }
}

// MARK: - Errors

enum WalletError: LocalizedError {
    case noCurrentUser
    case invalidWallet
    case walletCreationFailed
    case cannotDeletePrimaryWallet
    case balanceFetchFailed

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No user is currently logged in."
        case .invalidWallet:
            return "Invalid wallet."
        case .walletCreationFailed:
            return "Failed to create wallet. Please try again."
        case .cannotDeletePrimaryWallet:
            return "Cannot delete primary wallet. Please set another wallet as primary first."
        case .balanceFetchFailed:
            return "Failed to fetch wallet balance."
        }
    }
}
