import Foundation
import SwiftData
import Combine

/// ViewModel for transaction management
@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var transactions: [LocalTransaction] = []
    @Published var recentTransactions: [LocalTransaction] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var selectedTransaction: LocalTransaction?

    // Send transaction state
    @Published var recipientAddress: String = ""
    @Published var recipientZunoTag: String = ""
    @Published var amount: String = ""
    @Published var tokenSymbol: String = "USDC"
    @Published var transactionDescription: String = ""
    @Published var useZunoTag: Bool = false

    private let transactionService: TransactionService
    private let modelContext: ModelContext
    private var currentWallet: LocalWallet?
    private var currentUser: LocalUser?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.transactionService = TransactionService(modelContext: modelContext)
    }

    // MARK: - Setup

    /// Set current wallet and load transactions
    func setCurrentWallet(_ wallet: LocalWallet) async {
        self.currentWallet = wallet
        await transactionService.setCurrentWallet(wallet)
        await loadTransactions()
    }

    /// Set current user for all-wallet transaction queries
    func setCurrentUser(_ user: LocalUser) async {
        self.currentUser = user
    }

    // MARK: - Transaction Loading

    /// Load transactions from local database
    func loadTransactions() async {
        isLoading = true
        await transactionService.loadTransactions()
        self.transactions = transactionService.transactions
        self.recentTransactions = Array(transactions.prefix(20))
        isLoading = false
    }

    /// Refresh transactions from API
    func refreshTransactions() async {
        guard currentWallet != nil else { return }

        isLoading = true
        errorMessage = nil
        showError = false

        await transactionService.loadTransactions(forceRefresh: true)
        self.transactions = transactionService.transactions
        self.recentTransactions = Array(transactions.prefix(20))

        isLoading = false
    }

    /// Load all transactions across all user wallets
    func loadAllTransactions() async {
        guard let user = currentUser else { return }

        isLoading = true
        await transactionService.loadAllTransactions(for: user)
        self.transactions = transactionService.transactions
        self.recentTransactions = Array(transactions.prefix(20))
        isLoading = false
    }

    /// Refresh all transactions from API
    func refreshAllTransactions() async {
        guard let user = currentUser else { return }

        isLoading = true
        errorMessage = nil
        showError = false

        await transactionService.loadAllTransactions(for: user, forceRefresh: true)
        self.transactions = transactionService.transactions
        self.recentTransactions = Array(transactions.prefix(20))

        isLoading = false
    }

    // MARK: - Send Transaction

    /// Validate send transaction form
    func validateSendForm() -> ValidationResult {
        // Validate amount
        guard !amount.isEmpty else {
            return .invalid("Please enter an amount")
        }

        guard let amountValue = Double(amount), amountValue > 0 else {
            return .invalid("Please enter a valid amount greater than zero")
        }

        // Validate recipient
        if useZunoTag {
            guard !recipientZunoTag.isEmpty else {
                return .invalid("Please enter a @zuno tag")
            }

            // Basic zuno tag validation
            let cleanTag = recipientZunoTag.hasPrefix("@") ? String(recipientZunoTag.dropFirst()) : recipientZunoTag
            guard cleanTag.count >= 3 else {
                return .invalid("@zuno tag must be at least 3 characters")
            }
        } else {
            guard !recipientAddress.isEmpty else {
                return .invalid("Please enter a recipient address")
            }

            // Basic address validation (length check)
            guard recipientAddress.count >= 20 else {
                return .invalid("Please enter a valid wallet address")
            }
        }

        return .valid
    }

    /// Send transaction
    func sendTransaction(blockchain: String) async -> Bool {
        let validation = validateSendForm()
        guard validation.isValid else {
            self.errorMessage = validation.errorMessage
            self.showError = true
            return false
        }

        isLoading = true
        errorMessage = nil
        showError = false

        do {
            if useZunoTag {
                _ = try await transactionService.sendToZunoTag(
                    toZunoTag: recipientZunoTag,
                    amount: amount,
                    tokenSymbol: tokenSymbol,
                    blockchain: blockchain,
                    description: transactionDescription.isEmpty ? nil : transactionDescription
                )
            } else {
                _ = try await transactionService.sendToAddress(
                    toAddress: recipientAddress,
                    amount: amount,
                    tokenSymbol: tokenSymbol,
                    blockchain: blockchain,
                    description: transactionDescription.isEmpty ? nil : transactionDescription
                )
            }

            // Clear form
            clearSendForm()

            // Reload transactions
            await loadTransactions()

            isLoading = false
            return true

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            isLoading = false
            return false
        }
    }

    /// Clear send transaction form
    func clearSendForm() {
        recipientAddress = ""
        recipientZunoTag = ""
        amount = ""
        transactionDescription = ""
    }

    // MARK: - Transaction Details

    /// Select a transaction to view details
    func selectTransaction(_ transaction: LocalTransaction) {
        self.selectedTransaction = transaction
    }

    /// Get transaction by ID
    func getTransaction(id: String) async -> LocalTransaction? {
        do {
            return try await transactionService.getTransaction(id: id)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            return nil
        }
    }

    /// Refresh transaction status
    func refreshTransactionStatus(_ transaction: LocalTransaction) async {
        do {
            let updated = try await transactionService.refreshTransaction(transaction)
            self.selectedTransaction = updated
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Transaction History Filtering

    /// Get transactions by status
    func filterByStatus(_ status: TransactionStatus) async {
        do {
            self.transactions = try await transactionService.getTransactions(status: status)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    /// Get transactions by type
    func filterByType(_ type: TransactionType) async {
        do {
            self.transactions = try await transactionService.getTransactions(type: type)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    /// Get transactions for date range
    func filterByDateRange(from startDate: Date, to endDate: Date) async {
        do {
            self.transactions = try await transactionService.getTransactions(from: startDate, to: endDate)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    /// Clear filters and show all transactions
    func clearFilters() async {
        await loadTransactions()
    }

    // MARK: - Statistics

    /// Get total sent amount
    func getTotalSent(tokenSymbol: String? = nil) async -> Double {
        do {
            return try await transactionService.getTotalSent(tokenSymbol: tokenSymbol)
        } catch {
            print("Error getting total sent: \(error)")
            return 0.0
        }
    }

    /// Get total received amount
    func getTotalReceived(tokenSymbol: String? = nil) async -> Double {
        do {
            return try await transactionService.getTotalReceived(tokenSymbol: tokenSymbol)
        } catch {
            print("Error getting total received: \(error)")
            return 0.0
        }
    }

    /// Get pending transaction count
    func getPendingCount() async -> Int {
        do {
            return try await transactionService.getTransactionCount(status: .pending)
        } catch {
            print("Error getting pending count: \(error)")
            return 0
        }
    }

    // MARK: - Helper Methods

    /// Format amount for display
    func formatAmount(_ amount: String, symbol: String) -> String {
        guard let value = Double(amount) else { return "\(amount) \(symbol)" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6

        if let formatted = formatter.string(from: NSNumber(value: value)) {
            return "\(formatted) \(symbol)"
        }

        return "\(amount) \(symbol)"
    }

    /// Get transaction icon
    func getTransactionIcon(_ transaction: LocalTransaction) -> String {
        return transaction.transactionType.icon
    }

    /// Get transaction status color
    func getStatusColor(_ transaction: LocalTransaction) -> String {
        return transaction.statusColor
    }

    // MARK: - Error Handling

    /// Clear error message
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
