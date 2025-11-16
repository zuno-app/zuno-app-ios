import Foundation
import SwiftData
import Combine

/// ViewModel for wallet management
@MainActor
final class WalletViewModel: ObservableObject {
    @Published var wallets: [LocalWallet] = []
    @Published var primaryWallet: LocalWallet?
    @Published var selectedWallet: LocalWallet?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private let walletService: WalletService
    private let modelContext: ModelContext
    private var currentUser: LocalUser?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.walletService = WalletService(modelContext: modelContext)
    }

    // MARK: - Setup

    /// Set current user and load wallets
    func setCurrentUser(_ user: LocalUser) async {
        self.currentUser = user
        await walletService.setCurrentUser(user)
        await loadWallets()
    }

    // MARK: - Wallet Loading

    /// Load wallets from local database
    func loadWallets() async {
        isLoading = true
        await walletService.loadWallets()
        self.wallets = walletService.wallets
        self.primaryWallet = walletService.primaryWallet
        self.selectedWallet = primaryWallet ?? wallets.first
        isLoading = false
    }

    /// Refresh wallets from API
    func refreshWallets() async {
        isLoading = true
        errorMessage = nil
        showError = false

        await walletService.loadWallets(forceRefresh: true)
        self.wallets = walletService.wallets
        self.primaryWallet = walletService.primaryWallet
        self.selectedWallet = primaryWallet ?? wallets.first

        isLoading = false
    }

    // MARK: - Wallet Creation

    /// Create a new wallet
    func createWallet(blockchain: String, name: String? = nil) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let wallet = try await walletService.createWallet(blockchain: blockchain, name: name)
            await loadWallets()

            // If this is the first wallet, select it
            if selectedWallet == nil {
                selectedWallet = wallet
            }

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    // MARK: - Wallet Selection

    /// Select a wallet
    func selectWallet(_ wallet: LocalWallet) {
        self.selectedWallet = wallet
    }

    /// Set primary wallet
    func setPrimaryWallet(_ wallet: LocalWallet) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            try await walletService.setPrimaryWallet(wallet)
            await loadWallets()

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    // MARK: - Balance Management

    /// Get balance for selected wallet
    func getBalance() async -> WalletBalance? {
        guard let wallet = selectedWallet else { return nil }

        do {
            return try await walletService.getBalance(for: wallet)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            return nil
        }
    }

    /// Refresh balances for all wallets
    func refreshBalances() async {
        await walletService.refreshBalances()
        await loadWallets()
    }

    // MARK: - Wallet Lookup

    /// Lookup wallet by @zuno tag
    func lookupWallet(byZunoTag tag: String) async -> ZunoTagLookupResponse? {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let result = try await walletService.lookupWallet(byZunoTag: tag)
            isLoading = false
            return result
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            isLoading = false
            return nil
        }
    }

    // MARK: - Wallet Deletion

    /// Delete a wallet
    func deleteWallet(_ wallet: LocalWallet) async {
        isLoading = true
        errorMessage = nil
        showError = false

        do {
            try await walletService.deleteWallet(wallet)
            await loadWallets()

        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// Get wallet by blockchain
    func getWallet(for blockchain: String) -> LocalWallet? {
        return wallets.first { $0.blockchain == blockchain }
    }

    /// Get total balance across all wallets (in USD)
    func getTotalBalanceUSD() -> Double {
        return wallets.reduce(0.0) { total, wallet in
            total + (wallet.balanceUSD ?? 0.0)
        }
    }

    /// Get formatted total balance
    func getFormattedTotalBalance() -> String {
        let total = getTotalBalanceUSD()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }

    // MARK: - Error Handling

    /// Clear error message
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
