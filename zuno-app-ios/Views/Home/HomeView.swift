import SwiftUI
import SwiftData

/// Home dashboard - main screen after login
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var walletViewModel: WalletViewModel
    @StateObject private var transactionViewModel: TransactionViewModel

    @State private var showingSend = false
    @State private var showingReceive = false
    @State private var showingSettings = false
    @State private var isRefreshing = false

    init(modelContext: ModelContext) {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: modelContext))
        _walletViewModel = StateObject(wrappedValue: WalletViewModel(modelContext: modelContext))
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
                SendView(modelContext: modelContext)
            }
            .sheet(isPresented: $showingReceive) {
                ReceiveView(wallet: walletViewModel.primaryWallet)
            }
            .task {
                await setupView()
            }
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(spacing: 16) {
            // Total Balance
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(walletViewModel.getFormattedTotalBalance())
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.primary)
            }

            // Primary Wallet Info
            if let primaryWallet = walletViewModel.primaryWallet {
                VStack(spacing: 4) {
                    Text(primaryWallet.blockchainDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(primaryWallet.shortAddress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
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

                NavigationLink {
                    TransactionListView(modelContext: modelContext)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            if transactionViewModel.recentTransactions.isEmpty {
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

                Button {
                    // TODO: Add wallet
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(walletViewModel.wallets) { wallet in
                        WalletCard(wallet: wallet, isSelected: wallet.id == walletViewModel.selectedWallet?.id)
                            .onTapGesture {
                                walletViewModel.selectWallet(wallet)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - User Profile Button

    private var userProfileButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            if let user = authViewModel.currentUser {
                VStack(alignment: .leading, spacing: 2) {
                    if let displayName = user.displayName {
                        Text(displayName)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    Text("@\(user.zunoTag)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Setup and Refresh

    private func setupView() async {
        if let user = authViewModel.currentUser {
            await walletViewModel.setCurrentUser(user)
            await transactionViewModel.setCurrentUser(user)
            await transactionViewModel.loadAllTransactions()
        }
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

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.transactionType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(transaction.recipientDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.isIncoming ? "+" : "-")\(transaction.amount) \(transaction.tokenSymbol)")
                    .font(.subheadline.bold())
                    .foregroundStyle(transaction.isIncoming ? .green : .primary)

                HStack(spacing: 4) {
                    Image(systemName: transaction.statusIcon)
                        .font(.caption2)
                    Text(transaction.status.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(statusColor)
            }
        }
        .padding()
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
        case .confirmed: return .green
        case .failed, .cancelled: return .red
        }
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    let wallet: LocalWallet
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(wallet.blockchainDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if wallet.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            if let balance = wallet.balance {
                Text("\(balance) \(wallet.blockchain.contains("USDC") ? "USDC" : "ETH")")
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                Text("Loading...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(wallet.shortAddress)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160)
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    HomeView(modelContext: ModelContext(ModelContainer.preview))
}
