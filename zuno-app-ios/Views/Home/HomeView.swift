import SwiftUI
import SwiftData
import Combine

/// Home dashboard - main screen after login
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @StateObject private var transactionViewModel: TransactionViewModel

    @State private var showingSend = false
    @State private var showingReceive = false
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingBalanceDistribution = false
    @State private var isRefreshing = false
    
    // Fast auto-refresh timer for near real-time updates (5 seconds)
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(modelContext: ModelContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Balance Card
                        balanceCard

                        // Quick Actions
                        quickActionsRow

                        // Recent Transactions
                        recentTransactionsSection

                        // Wallets Section
                        walletsSection
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Zuno Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    userProfileButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSend) {
                SendView(modelContext: modelContext, preselectedWallet: walletViewModel.primaryWallet)
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingReceive) {
                ReceiveView(wallet: walletViewModel.primaryWallet)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(modelContext: modelContext)
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingProfile) {
                if let user = authViewModel.currentUser {
                    UserProfileView(
                        user: user,
                        walletCount: walletViewModel.wallets.count,
                        totalBalance: walletViewModel.getFormattedTotalBalance(),
                        modelContext: modelContext
                    )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showingBalanceDistribution) {
                BalanceDistributionView()
                    .environmentObject(authViewModel)
                    .environmentObject(walletViewModel)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
            .task {
                await setupView()
            }
            .onReceive(refreshTimer) { _ in
                // Auto-refresh balance and transactions every 5 seconds for near real-time
                Task {
                    await autoRefresh()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Refresh immediately when app comes to foreground
                if newPhase == .active {
                    print("📱 [HomeView] App became active - refreshing data")
                    Task {
                        await refreshData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionReceived)) { notification in
                if let event = notification.object as? TransactionEvent {
                    showTransactionNotification(event)
                }
            }
        }
    }
    
    // MARK: - Auto Refresh (Silent)
    
    private func autoRefresh() async {
        // Silent refresh - don't show loading indicators
        // This runs every 5 seconds for near real-time updates
        await walletViewModel.fetchAggregatedBalance()
        await transactionViewModel.refreshAllTransactions()
    }
    
    // MARK: - Real-Time Transaction Notifications
    
    private func showTransactionNotification(_ event: TransactionEvent) {
        let isIncoming = event.transactionType == "receive"
        let symbol = event.tokenSymbol
        let amount = event.amount
        
        print("🔔 [HomeView] \(isIncoming ? "💰 Received" : "💸 Sent"): \(amount) \(symbol)")
        
        // Haptic feedback for new transactions
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Refresh data immediately
        Task {
            await walletViewModel.fetchAggregatedBalance()
            await transactionViewModel.refreshAllTransactions()
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        Button {
            showingBalanceDistribution = true
        } label: {
            VStack(spacing: 16) {
                // Total Balance
                VStack(spacing: 8) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Text(walletViewModel.getFormattedTotalBalance())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    
                    // Preferred Stablecoin indicator
                    if authViewModel.currentUser != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption2)
                            Text("Preferred: \(walletViewModel.getPreferredStablecoin())")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                }

                // Primary Wallet Info
                if let primaryWallet = walletViewModel.primaryWallet {
                    VStack(spacing: 4) {
                        Text(primaryWallet.blockchainDisplayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(primaryWallet.shortAddress)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                
                // Tap hint
                HStack(spacing: 4) {
                    Text("Tap for details")
                        .font(.caption2)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                icon: "arrow.up.right",
                title: "Send",
                color: .blue
            ) {
                showingSend = true
            }

            QuickActionButton(
                icon: "arrow.down.left",
                title: "Receive",
                color: .green
            ) {
                showingReceive = true
            }

            QuickActionButton(
                icon: "arrow.left.arrow.right",
                title: "Swap",
                color: .orange
            ) {
                // TODO: Implement swap
            }

            QuickActionButton(
                icon: "plus",
                title: "Buy",
                color: .purple
            ) {
                // TODO: Implement buy
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)

                Spacer()

                if transactionViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                NavigationLink {
                    TransactionListView(modelContext: modelContext)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            if transactionViewModel.isLoading && transactionViewModel.recentTransactions.isEmpty {
                loadingTransactionsView
            } else if transactionViewModel.recentTransactions.isEmpty {
                emptyTransactionsView
            } else {
                VStack(spacing: 0) {
                    ForEach(transactionViewModel.recentTransactions.prefix(5)) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        if transaction.id != transactionViewModel.recentTransactions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: transactionViewModel.recentTransactions.count)
    }
    
    private var loadingTransactionsView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var emptyTransactionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No transactions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start by sending or receiving crypto")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Wallets Section

    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Wallets")
                    .font(.headline)

                Spacer()

                if walletViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button {
                    Task {
                        await walletViewModel.createWallet(blockchain: "ARC_TESTNET", name: "My Wallet")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(walletViewModel.isLoading)
            }
            .padding(.horizontal)

            if walletViewModel.isLoading && walletViewModel.wallets.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Creating wallet...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else if walletViewModel.wallets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No wallets yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        Task {
                            await walletViewModel.createWallet(blockchain: "ARC_TESTNET", name: "My First Wallet")
                        }
                    } label: {
                        Label("Create Wallet", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(walletViewModel.isLoading)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(walletViewModel.wallets) { wallet in
                            NavigationLink {
                                WalletDetailView(wallet: wallet)
                                    .environmentObject(walletViewModel)
                            } label: {
                                WalletCard(
                                    wallet: wallet,
                                    isSelected: wallet.id == walletViewModel.selectedWallet?.id,
                                    balanceInfo: walletViewModel.getFormattedBalanceForWallet(wallet)
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                walletViewModel.selectWallet(wallet)
                            })
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: walletViewModel.wallets.count)
            }
        }
    }

    // MARK: - User Profile Button

    private var userProfileButton: some View {
        Button {
            showingProfile = true
        } label: {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        }
    }

    // MARK: - Setup and Refresh

    private func setupView() async {
        print("✅ [HomeView] HomeView appeared for user: \(authViewModel.currentUser?.zunoTag ?? "unknown")")
        print("📊 [HomeView] Wallets already loaded: \(walletViewModel.wallets.count)")
        
        guard let user = authViewModel.currentUser else {
            print("⚠️ [HomeView] No user found - this shouldn't happen")
            return
        }
        
        // WalletViewModel is already set up from AuthenticatedView
        // Just set up transaction view model
        await transactionViewModel.setCurrentUser(user)
        await transactionViewModel.loadAllTransactions()
        
        // Fetch aggregated balance for accurate display
        await walletViewModel.fetchAggregatedBalance()
    }

    private func refreshData() async {
        isRefreshing = true
        await walletViewModel.refreshWallets()
        await walletViewModel.refreshBalances()
        await transactionViewModel.refreshAllTransactions()
        isRefreshing = false
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: LocalTransaction
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.transactionType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionType.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(transaction.recipientDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.isIncoming ? "+" : "-")\(formatAmount(transaction.amount)) \(transaction.tokenSymbol)")
                    .font(.subheadline.bold())
                    .foregroundStyle(transaction.isIncoming ? .green : .primary)

                HStack(spacing: 4) {
                    if transaction.status == .pending || transaction.status == .confirming {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: transaction.statusIcon)
                            .font(.caption2)
                    }
                    Text(transaction.status.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(statusColor)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var iconColor: Color {
        transaction.isIncoming ? .green : .blue
    }

    private var iconBackgroundColor: Color {
        transaction.isIncoming ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)
    }

    private var statusColor: Color {
        switch transaction.status {
        case .pending: return .orange
        case .confirming: return .orange
        case .confirmed: return .green
        case .failed, .cancelled: return .red
        }
    }
    
    /// Format amount for display - removes excessive decimals and handles large numbers
    private func formatAmount(_ amount: String) -> String {
        // Handle both comma and period as decimal separators
        let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
        
        guard let value = Double(normalizedAmount) else {
            return amount
        }
        
        // Format based on value size
        if value == 0 {
            return "0"
        } else if value >= 1000 {
            // Large amounts: no decimals
            return String(format: "%.0f", value)
        } else if value >= 1 {
            // Normal amounts: 2 decimals
            return String(format: "%.2f", value)
        } else if value >= 0.01 {
            // Small amounts: 2 decimals
            return String(format: "%.2f", value)
        } else {
            // Very small amounts: up to 4 decimals
            return String(format: "%.4f", value)
        }
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    let wallet: LocalWallet
    let isSelected: Bool
    let balanceInfo: (amount: String, symbol: String, fiatValue: String)?
    @State private var isPressed = false
    
    init(wallet: LocalWallet, isSelected: Bool, balanceInfo: (amount: String, symbol: String, fiatValue: String)? = nil) {
        self.wallet = wallet
        self.isSelected = isSelected
        self.balanceInfo = balanceInfo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(wallet.blockchainDisplayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if wallet.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.3), radius: 2)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(balanceInfo?.amount ?? wallet.balance ?? "0")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(balanceInfo?.symbol ?? wallet.tokenSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(wallet.shortAddress)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? Color.blue.opacity(0.2) : Color.clear, radius: 8)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([LocalUser.self, LocalWallet.self, LocalTransaction.self, CachedData.self, AppSettings.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        HomeView(modelContext: context)
            .environmentObject(AuthViewModel(modelContext: context))
            .environmentObject(WalletViewModel(modelContext: context))
    }
}
