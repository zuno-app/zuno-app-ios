//
//  WalletDetailView.swift
//  zuno-app-ios
//
//  Created on 11/24/25.
//

import SwiftUI
import SwiftData

/// Detailed view for a single wallet
struct WalletDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel
    
    let wallet: LocalWallet
    
    @State private var transactions: [LocalTransaction] = []
    @State private var isLoadingTransactions = false
    @State private var showingOptions = false
    @State private var showingDeleteConfirmation = false
    @State private var isRefreshing = false
    @State private var showingSend = false
    @State private var showingReceive = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Wallet Header
                walletHeader
                
                // Balance Card
                balanceCard
                
                // Quick Actions
                quickActions
                
                // Wallet Info
                walletInfo
                
                // Recent Transactions
                recentTransactions
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(wallet.name ?? "Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingOptions = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Wallet Options", isPresented: $showingOptions) {
            Button("Set as Primary") {
                // TODO: Implement
            }
            .disabled(wallet.isPrimary)
            
            Button("Rename") {
                // TODO: Implement
            }
            
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .disabled(wallet.isPrimary)
            
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete Wallet", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteWallet()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this wallet? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSend) {
            SendView(modelContext: modelContext, preselectedWallet: wallet)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReceive) {
            ReceiveView(wallet: wallet)
                .presentationDragIndicator(.visible)
        }
        .refreshable {
            await refreshWallet()
        }
        .task {
            await loadTransactions()
        }
    }
    
    // MARK: - Wallet Header
    
    private var walletHeader: some View {
        VStack(spacing: 12) {
            // Blockchain Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "network")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10)
            
            // Blockchain Name
            Text(wallet.blockchainDisplayName)
                .font(.title2.bold())
            
            // Primary Badge
            if wallet.isPrimary {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("Primary Wallet")
                        .font(.caption)
                }
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        let balanceInfo = walletViewModel.getFormattedBalanceForWallet(wallet)
        
        return VStack(spacing: 16) {
            // Balance
            VStack(spacing: 8) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Show balance from aggregated data or fallback
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(balanceInfo.amount)
                        .font(.system(size: 36, weight: .bold))
                    Text(balanceInfo.symbol)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Fiat Value
            Text("≈ \(balanceInfo.fiatValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Address
            VStack(spacing: 8) {
                Text("Wallet Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Text(wallet.shortAddress)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                    
                    Button {
                        UIPasteboard.general.string = wallet.walletAddress
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "arrow.up.right", title: "Send", color: .blue) {
                showingSend = true
            }
            
            ActionButton(icon: "arrow.down.left", title: "Receive", color: .green) {
                showingReceive = true
            }
            
            ActionButton(icon: "arrow.left.arrow.right", title: "Swap", color: .orange) {
                // TODO: Navigate to swap
            }
        }
    }
    
    // MARK: - Wallet Info
    
    private var walletInfo: some View {
        VStack(spacing: 0) {
            InfoRow(label: "Network", value: wallet.blockchainDisplayName)
            Divider().padding(.leading, 16)
            
            InfoRow(label: "Account Type", value: wallet.accountType.capitalized)
            Divider().padding(.leading, 16)
            
            InfoRow(label: "Created", value: wallet.createdAt.formatted(date: .abbreviated, time: .omitted))
            Divider().padding(.leading, 16)
            
            InfoRow(label: "Last Updated", value: wallet.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Transactions
    
    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .padding(.horizontal, 4)
                
                Spacer()
                
                if isLoadingTransactions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if isLoadingTransactions && transactions.isEmpty {
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
            } else if transactions.isEmpty {
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
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions.prefix(5)) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            WalletTransactionRow(transaction: transaction, tokenSymbol: wallet.tokenSymbol)
                        }
                        .buttonStyle(.plain)
                        
                        if transaction.id != transactions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTransactions() async {
        isLoadingTransactions = true
        
        do {
            // Fetch transactions for this wallet from local database
            let walletId = wallet.id
            let descriptor = FetchDescriptor<LocalTransaction>(
                predicate: #Predicate { $0.walletId == walletId }
            )
            let fetchedTransactions = try modelContext.fetch(descriptor)
            transactions = fetchedTransactions.sorted { $0.createdAt > $1.createdAt }
            
            // Also try to refresh from API
            let apiTransactions = try await APIClient.shared.getTransactions()
            
            // Save new transactions to local database
            // Use wallet_id from API response to correctly associate transactions
            for response in apiTransactions {
                // Check if transaction already exists
                let txId = response.id
                let existingDescriptor = FetchDescriptor<LocalTransaction>(
                    predicate: #Predicate { $0.id == txId }
                )
                let existing = try modelContext.fetch(existingDescriptor)
                
                if existing.isEmpty {
                    // Use wallet_id from API response (not current wallet)
                    let newTransaction = LocalTransaction.from(response)
                    
                    // Find the correct wallet for this transaction
                    let responseWalletId = response.walletId
                    let walletDescriptor = FetchDescriptor<LocalWallet>(
                        predicate: #Predicate { $0.id == responseWalletId }
                    )
                    if let matchingWallet = try? modelContext.fetch(walletDescriptor).first {
                        newTransaction.wallet = matchingWallet
                    }
                    
                    modelContext.insert(newTransaction)
                } else if let existingTx = existing.first {
                    // Update existing transaction with correct wallet_id if needed
                    if existingTx.walletId != response.walletId {
                        existingTx.walletId = response.walletId
                        let responseWalletId = response.walletId
                        let walletDescriptor = FetchDescriptor<LocalWallet>(
                            predicate: #Predicate { $0.id == responseWalletId }
                        )
                        if let matchingWallet = try? modelContext.fetch(walletDescriptor).first {
                            existingTx.wallet = matchingWallet
                        }
                    }
                }
            }
            
            try modelContext.save()
            
            // Reload from database - only transactions for THIS wallet
            let updatedTransactions = try modelContext.fetch(descriptor)
            transactions = updatedTransactions.sorted { $0.createdAt > $1.createdAt }
            
        } catch {
            print("❌ [WalletDetailView] Error loading transactions: \(error)")
        }
        
        isLoadingTransactions = false
    }
    
    private func refreshWallet() async {
        isRefreshing = true
        await walletViewModel.fetchAggregatedBalance()
        await loadTransactions()
        isRefreshing = false
    }
    
    private func deleteWallet() {
        // TODO: Implement wallet deletion
        dismiss()
    }
}

// MARK: - Wallet Transaction Row

struct WalletTransactionRow: View {
    let transaction: LocalTransaction
    let tokenSymbol: String
    
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.isIncoming ? "+" : "-")\(transaction.amount) \(transaction.tokenSymbol)")
                    .font(.subheadline.bold())
                    .foregroundStyle(transaction.isIncoming ? .green : .primary)
                
                HStack(spacing: 4) {
                    if transaction.status == .pending {
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
    }
    
    private var iconColor: Color {
        transaction.isIncoming ? .green : .blue
    }
    
    private var iconBackgroundColor: Color {
        transaction.isIncoming ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .pending, .confirming: return .orange
        case .confirmed: return .green
        case .failed, .cancelled: return .red
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct WalletDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let wallet = LocalWallet(
            id: "wallet_123",
            walletAddress: "0x1234567890abcdef1234567890abcdef12345678",
            blockchain: "ARC_TESTNET",
            accountType: "SCA",
            userId: "user_123",
            isPrimary: true,
            name: "My Wallet"
        )
        
        NavigationStack {
            WalletDetailView(wallet: wallet)
        }
    }
}
