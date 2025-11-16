import Foundation
import SwiftData

/// Service for transaction management
@MainActor
final class TransactionService: ObservableObject {
    @Published var transactions: [LocalTransaction] = []
    @Published var isLoading: Bool = false

    private let modelContext: ModelContext
    private var currentWallet: LocalWallet?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Set the current wallet and load transactions
    func setCurrentWallet(_ wallet: LocalWallet) async {
        self.currentWallet = wallet
        await loadTransactions()
    }

    // MARK: - Transaction Management

    /// Load transactions from local database and sync with API
    func loadTransactions(forceRefresh: Bool = false) async {
        guard let wallet = currentWallet else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            if forceRefresh {
                // Fetch from API
                let transactionResponses = try await APIClient.shared.getTransactions()

                // Save to local database
                for response in transactionResponses {
                    try await saveTransaction(response, for: wallet)
                }
            }

            // Load from local database
            let descriptor = FetchDescriptor<LocalTransaction>(
                predicate: #Predicate { $0.wallet?.id == wallet.id },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.transactions = try modelContext.fetch(descriptor)

        } catch {
            print("Error loading transactions: \(error)")
        }
    }

    /// Load all transactions for user (across all wallets)
    func loadAllTransactions(for user: LocalUser, forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if forceRefresh {
                // Fetch from API
                let transactionResponses = try await APIClient.shared.getTransactions()

                // Get all user's wallets
                let walletDescriptor = FetchDescriptor<LocalWallet>(
                    predicate: #Predicate { $0.user?.id == user.id }
                )
                let wallets = try modelContext.fetch(walletDescriptor)

                // Save transactions (matching by wallet if possible)
                for response in transactionResponses {
                    if let wallet = wallets.first {
                        try await saveTransaction(response, for: wallet)
                    }
                }
            }

            // Load all transactions for user's wallets
            let descriptor = FetchDescriptor<LocalTransaction>(
                predicate: #Predicate { $0.wallet?.user?.id == user.id },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.transactions = try modelContext.fetch(descriptor)

        } catch {
            print("Error loading all transactions: \(error)")
        }
    }

    // MARK: - Send Transaction

    /// Send transaction to address
    func sendToAddress(
        toAddress: String,
        amount: String,
        tokenSymbol: String,
        blockchain: String,
        description: String? = nil
    ) async throws -> LocalTransaction {
        guard let wallet = currentWallet else {
            throw TransactionError.noCurrentWallet
        }

        isLoading = true
        defer { isLoading = false }

        // Validate amount
        guard let amountValue = Double(amount), amountValue > 0 else {
            throw TransactionError.invalidAmount
        }

        // Send transaction via API
        let transactionResponse = try await APIClient.shared.sendTransaction(
            toAddress: toAddress,
            toZunoTag: nil,
            amount: amount,
            tokenSymbol: tokenSymbol,
            blockchain: blockchain
        )

        // Save to local database
        let localTransaction = try await saveTransaction(transactionResponse, for: wallet)

        // Reload transactions
        await loadTransactions()

        return localTransaction
    }

    /// Send transaction to @zuno tag
    func sendToZunoTag(
        toZunoTag: String,
        amount: String,
        tokenSymbol: String,
        blockchain: String,
        description: String? = nil
    ) async throws -> LocalTransaction {
        guard let wallet = currentWallet else {
            throw TransactionError.noCurrentWallet
        }

        isLoading = true
        defer { isLoading = false }

        // Validate amount
        guard let amountValue = Double(amount), amountValue > 0 else {
            throw TransactionError.invalidAmount
        }

        // Remove @ prefix if present
        let cleanTag = toZunoTag.hasPrefix("@") ? String(toZunoTag.dropFirst()) : toZunoTag

        // Send transaction via API
        let transactionResponse = try await APIClient.shared.sendTransaction(
            toAddress: nil,
            toZunoTag: cleanTag,
            amount: amount,
            tokenSymbol: tokenSymbol,
            blockchain: blockchain
        )

        // Save to local database
        let localTransaction = try await saveTransaction(transactionResponse, for: wallet)

        // Reload transactions
        await loadTransactions()

        return localTransaction
    }

    // MARK: - Transaction Details

    /// Get transaction by ID
    func getTransaction(id: String) async throws -> LocalTransaction {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        let transactions = try modelContext.fetch(descriptor)

        guard let transaction = transactions.first else {
            throw TransactionError.transactionNotFound
        }

        return transaction
    }

    /// Refresh transaction status
    func refreshTransaction(_ transaction: LocalTransaction) async throws -> LocalTransaction {
        // For now, we'll rely on polling or webhooks
        // TODO: Implement transaction status polling
        return transaction
    }

    // MARK: - Transaction History

    /// Get recent transactions (last 20)
    func getRecentTransactions() async throws -> [LocalTransaction] {
        let descriptor = FetchDescriptor<LocalTransaction>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        var allTransactions = try modelContext.fetch(descriptor)

        // Limit to 20
        if allTransactions.count > 20 {
            allTransactions = Array(allTransactions.prefix(20))
        }

        return allTransactions
    }

    /// Get transactions filtered by status
    func getTransactions(status: TransactionStatus) async throws -> [LocalTransaction] {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.status == status },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get transactions filtered by type
    func getTransactions(type: TransactionType) async throws -> [LocalTransaction] {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.transactionType == type },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get transactions for date range
    func getTransactions(from startDate: Date, to endDate: Date) async throws -> [LocalTransaction] {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { transaction in
                transaction.createdAt >= startDate && transaction.createdAt <= endDate
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Statistics

    /// Calculate total sent amount
    func getTotalSent(tokenSymbol: String? = nil) async throws -> Double {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.transactionType == .send && $0.status == .confirmed }
        )
        let sentTransactions = try modelContext.fetch(descriptor)

        var total: Double = 0.0
        for tx in sentTransactions {
            if let symbol = tokenSymbol, tx.tokenSymbol != symbol {
                continue
            }
            if let amount = Double(tx.amount) {
                total += amount
            }
        }

        return total
    }

    /// Calculate total received amount
    func getTotalReceived(tokenSymbol: String? = nil) async throws -> Double {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.transactionType == .receive && $0.status == .confirmed }
        )
        let receivedTransactions = try modelContext.fetch(descriptor)

        var total: Double = 0.0
        for tx in receivedTransactions {
            if let symbol = tokenSymbol, tx.tokenSymbol != symbol {
                continue
            }
            if let amount = Double(tx.amount) {
                total += amount
            }
        }

        return total
    }

    /// Get transaction count by status
    func getTransactionCount(status: TransactionStatus) async throws -> Int {
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.status == status }
        )
        let transactions = try modelContext.fetch(descriptor)
        return transactions.count
    }

    // MARK: - Helper Methods

    /// Save or update transaction in local database
    private func saveTransaction(_ transactionResponse: TransactionResponse, for wallet: LocalWallet) async throws -> LocalTransaction {
        // Check if transaction already exists
        let descriptor = FetchDescriptor<LocalTransaction>(
            predicate: #Predicate { $0.id == transactionResponse.id }
        )
        let existingTransactions = try modelContext.fetch(descriptor)

        if let existingTransaction = existingTransactions.first {
            // Update existing transaction
            existingTransaction.status = TransactionStatus(rawValue: transactionResponse.status) ?? .pending
            existingTransaction.blockchainTxHash = transactionResponse.blockchainTxHash
            existingTransaction.updatedAt = Date()
            try modelContext.save()
            return existingTransaction
        } else {
            // Create new transaction
            let newTransaction = LocalTransaction.from(transactionResponse)
            newTransaction.wallet = wallet
            modelContext.insert(newTransaction)
            try modelContext.save()
            return newTransaction
        }
    }
}

// MARK: - Errors

enum TransactionError: LocalizedError {
    case noCurrentWallet
    case invalidAmount
    case invalidRecipient
    case insufficientBalance
    case transactionNotFound
    case transactionFailed

    var errorDescription: String? {
        switch self {
        case .noCurrentWallet:
            return "No wallet selected. Please select a wallet first."
        case .invalidAmount:
            return "Invalid amount. Please enter a valid number greater than zero."
        case .invalidRecipient:
            return "Invalid recipient address or @zuno tag."
        case .insufficientBalance:
            return "Insufficient balance to complete this transaction."
        case .transactionNotFound:
            return "Transaction not found."
        case .transactionFailed:
            return "Transaction failed. Please try again."
        }
    }
}
