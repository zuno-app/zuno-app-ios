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
    @Published var isCreatingWallet: Bool = false  // Track if wallet creation is in progress
    @Published var hasCheckedWallets: Bool = false  // Track if we've checked for wallets
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var walletCreationComplete: Bool = false  // Explicit flag for view transition
    
    // Aggregated balance data
    @Published var aggregatedBalance: AggregatedBalanceResponse?
    @Published var isLoadingBalance: Bool = false

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
        // If user changed, reset all state first
        if let currentUser = self.currentUser, currentUser.id != user.id {
            print("🔄 [WalletViewModel] User changed from \(currentUser.zunoTag) to \(user.zunoTag) - resetting state")
            resetStateSync()
        }
        
        self.currentUser = user
        await walletService.setCurrentUser(user)
        // Don't load here - will be done by refreshWallets() in setupView
    }
    
    // MARK: - State Reset
    
    /// Reset all wallet state synchronously (called when user changes or logs out)
    func resetStateSync() {
        print("🔄 [WalletViewModel] Resetting all wallet state (sync)")
        wallets = []
        primaryWallet = nil
        selectedWallet = nil
        isLoading = false
        isCreatingWallet = false
        walletCreationComplete = false
        hasCheckedWallets = false
        errorMessage = nil
        showError = false
        currentUser = nil
        aggregatedBalance = nil
        isLoadingBalance = false
        
        // Also clear the wallet service state
        walletService.clearState()
    }
    
    /// Reset all wallet state asynchronously
    func resetState() async {
        resetStateSync()
    }

    // MARK: - Wallet Loading

    /// Load wallets from local database
    func loadWallets() async {
        isLoading = true
        print("📥 [WalletViewModel] loadWallets() called")
        await walletService.loadWallets()
        print("📥 [WalletViewModel] walletService.wallets.count = \(walletService.wallets.count)")
        self.wallets = walletService.wallets
        self.primaryWallet = walletService.primaryWallet
        self.selectedWallet = primaryWallet ?? wallets.first
        self.hasCheckedWallets = true
        print("📥 [WalletViewModel] self.wallets.count = \(self.wallets.count)")
        
        // If we have wallets, ensure walletCreationComplete is true
        if !wallets.isEmpty && !walletCreationComplete {
            print("🔄 [WalletViewModel] Found wallets in loadWallets, setting walletCreationComplete = true")
            walletCreationComplete = true
        }
        
        isLoading = false
    }

    /// Refresh wallets from API
    func refreshWallets() async {
        // Don't refresh if wallet creation is in progress - it will handle its own loading
        guard !isCreatingWallet else {
            print("⏸️ [WalletViewModel] Skipping refreshWallets - wallet creation in progress")
            return
        }
        
        isLoading = true
        errorMessage = nil
        showError = false

        await walletService.loadWallets(forceRefresh: true)
        self.wallets = walletService.wallets
        self.primaryWallet = walletService.primaryWallet
        self.selectedWallet = primaryWallet ?? wallets.first
        
        // Mark that we've checked for wallets
        self.hasCheckedWallets = true
        print("📱 [WalletViewModel] Wallet check complete. Found \(wallets.count) wallets")
        
        // If we have wallets, ensure walletCreationComplete is true
        // This handles the case where the view re-renders after wallet creation
        if !wallets.isEmpty && !walletCreationComplete {
            print("🔄 [WalletViewModel] Found wallets, setting walletCreationComplete = true")
            walletCreationComplete = true
        }

        isLoading = false
    }

    // MARK: - Wallet Creation

    /// Create a new wallet
    func createWallet(blockchain: String, name: String? = nil) async {
        isLoading = true
        isCreatingWallet = true  // Prevent view switching during creation
        errorMessage = nil
        showError = false

        do {
            print("🌐 [WalletViewModel] Creating wallet on \(blockchain)...")
            let wallet = try await walletService.createWallet(blockchain: blockchain, name: name)
            print("✅ [WalletViewModel] Wallet created: \(wallet.walletAddress)")
            
            // Load wallets to update the array
            await loadWallets()
            print("📊 [WalletViewModel] After loadWallets: \(wallets.count) wallets")

            // If this is the first wallet, select it
            if selectedWallet == nil {
                selectedWallet = wallet
            }
            
            // Verify wallets array is populated before clearing isCreatingWallet
            if wallets.isEmpty {
                print("⚠️ [WalletViewModel] Wallets still empty after load, forcing refresh...")
                await refreshWallets()
                print("📊 [WalletViewModel] After refreshWallets: \(wallets.count) wallets")
            }

        } catch {
            print("❌ [WalletViewModel] Create wallet error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.showError = true
        }

        isLoading = false
        
        // Only clear isCreatingWallet after we have wallets (or error)
        // This ensures the view doesn't flicker back to onboarding
        print("🏁 [WalletViewModel] Finishing createWallet. wallets.count=\(wallets.count), hasError=\(errorMessage != nil)")
        
        // IMPORTANT: Ensure wallets array is populated before clearing isCreatingWallet
        // This prevents the view from briefly showing onboarding again
        if wallets.isEmpty && errorMessage == nil {
            print("⚠️ [WalletViewModel] Wallets still empty, doing final refresh...")
            await refreshWallets()
            print("📊 [WalletViewModel] Final refresh complete. wallets.count=\(wallets.count)")
        }
        
        isCreatingWallet = false  // Allow view switching after creation
        
        // Set explicit flag to trigger view transition
        if !wallets.isEmpty {
            print("🚀 [WalletViewModel] Setting walletCreationComplete = true")
            walletCreationComplete = true
        }
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
        await fetchAggregatedBalance()
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

    /// Fetch aggregated balance from API
    func fetchAggregatedBalance() async {
        isLoadingBalance = true
        do {
            let balance = try await APIClient.shared.getAggregatedBalance()
            aggregatedBalance = balance
            print("✅ [WalletViewModel] Fetched aggregated balance:")
            print("   - Total USD: \(balance.totalValueUsd)")
            print("   - Total in preferred fiat (\(balance.preferredFiat)): \(balance.totalInPreferredFiat)")
            print("   - Token breakdown count: \(balance.tokenBreakdown.count)")
            for token in balance.tokenBreakdown {
                print("   - \(token.tokenSymbol): \(token.amount) = \(balance.preferredFiat) \(token.valueGbp)")
            }
        } catch {
            print("❌ [WalletViewModel] Failed to fetch aggregated balance: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
        isLoadingBalance = false
    }
    
    /// Get total balance across all wallets (in USD)
    func getTotalBalanceUSD() -> Double {
        // Use aggregated balance if available
        if let balance = aggregatedBalance {
            return balance.totalValueUsd
        }
        // Fallback to wallet balances
        return wallets.reduce(0.0) { total, wallet in
            total + (wallet.balanceUSD ?? 0.0)
        }
    }

    /// Get formatted total balance
    func getFormattedTotalBalance() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        
        // Use aggregated balance if available (preferred)
        if let balance = aggregatedBalance {
            formatter.currencyCode = balance.preferredFiat
            return formatter.string(from: NSNumber(value: balance.totalInPreferredFiat)) ?? "$0.00"
        }
        
        // Fallback to calculated total
        let total = getTotalBalanceUSD()
        
        // Use user's preferred currency if available
        if let user = currentUser {
            formatter.currencyCode = user.defaultCurrency
        } else {
            formatter.currencyCode = "USD"
        }
        
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
    
    /// Get user's preferred stablecoin symbol
    func getPreferredStablecoin() -> String {
        guard let user = currentUser else { return "USDC" }
        
        // Use user's explicit preference if set
        if !user.preferredStablecoin.isEmpty {
            return user.preferredStablecoin
        }
        
        // Fallback: Return stablecoin based on user's currency preference
        switch user.defaultCurrency {
        case "EUR": return "EURC"
        case "GBP": return "GBPC"
        default: return "USDC"
        }
    }
    
    /// Get user's preferred fiat currency
    func getPreferredFiat() -> String {
        return currentUser?.defaultCurrency ?? "USD"
    }
    
    /// Get token balance info for a specific wallet address
    func getTokenBalanceForWallet(_ walletAddress: String) -> TokenBalanceInfo? {
        guard let balance = aggregatedBalance else { return nil }
        return balance.tokenBreakdown.first { $0.walletAddress == walletAddress }
    }
    
    /// Get formatted balance for a wallet (from aggregated balance)
    func getFormattedBalanceForWallet(_ wallet: LocalWallet) -> (amount: String, symbol: String, fiatValue: String) {
        if let tokenInfo = getTokenBalanceForWallet(wallet.walletAddress) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = getPreferredFiat()
            formatter.maximumFractionDigits = 2
            
            let fiatValue: Double
            switch getPreferredFiat() {
            case "EUR": fiatValue = tokenInfo.valueEur
            case "GBP": fiatValue = tokenInfo.valueGbp
            default: fiatValue = tokenInfo.valueUsd
            }
            
            let fiatString = formatter.string(from: NSNumber(value: fiatValue)) ?? "$0.00"
            return (String(format: "%.2f", tokenInfo.amount), tokenInfo.tokenSymbol, fiatString)
        }
        
        // Fallback to wallet's stored balance
        return (wallet.balance ?? "0", wallet.tokenSymbol, "$0.00")
    }

    // MARK: - Error Handling

    /// Clear error message
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
