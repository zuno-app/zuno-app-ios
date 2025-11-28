import SwiftUI
import Combine

/// View showing total balance distribution across all wallets and tokens
/// Displays values in user's preferred fiat and stablecoin with real-time updates
struct BalanceDistributionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastRefreshTime: Date = Date()
    
    // Use walletViewModel's aggregatedBalance for consistency
    private var aggregatedBalance: AggregatedBalanceResponse? {
        walletViewModel.aggregatedBalance
    }
    
    // Auto-refresh timer (5 seconds for real-time feel)
    let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && aggregatedBalance == nil {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let balance = aggregatedBalance {
                    balanceContent(balance)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Balance Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if isLoading || walletViewModel.isLoadingBalance {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await refreshBalance() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await refreshBalance()
            }
            .onReceive(refreshTimer) { _ in
                Task { await refreshBalance() }
            }
        }
    }
    
    // MARK: - Balance Content
    
    private func balanceContent(_ balance: AggregatedBalanceResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total Balance Card
                totalBalanceCard(balance)
                
                // Currency Breakdown
                currencyBreakdownSection(balance)
                
                // Token Distribution
                if !balance.tokenBreakdown.isEmpty {
                    tokenDistributionSection(balance)
                }
                
                // Last Updated
                lastUpdatedFooter(balance)
            }
            .padding()
        }
        .refreshable {
            await refreshBalance()
        }
    }
    
    // MARK: - Total Balance Card
    
    private func totalBalanceCard(_ balance: AggregatedBalanceResponse) -> some View {
        VStack(spacing: 16) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            // Main balance in preferred fiat
            VStack(spacing: 4) {
                Text(formatCurrency(balance.totalInPreferredFiat, currency: balance.preferredFiat))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(balance.preferredFiat)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.horizontal, 40)
            
            // Equivalent in preferred stablecoin
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("≈")
                        .foregroundStyle(.white.opacity(0.7))
                    Text(formatAmount(balance.totalInPreferredStablecoin))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(balance.preferredStablecoin)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Text("in \(balance.preferredStablecoin)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
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
    
    // MARK: - Currency Breakdown
    
    private func currencyBreakdownSection(_ balance: AggregatedBalanceResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency Breakdown")
                .font(.headline)
            
            VStack(spacing: 0) {
                currencyRow(
                    symbol: "USD",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    fiatValue: balance.totalValueUsd,
                    stablecoinValue: balance.totalValueUsdc,
                    stablecoinSymbol: "USDC"
                )
                
                Divider().padding(.leading, 50)
                
                currencyRow(
                    symbol: "EUR",
                    icon: "eurosign.circle.fill",
                    color: .blue,
                    fiatValue: balance.totalValueEur,
                    stablecoinValue: balance.totalValueEurc,
                    stablecoinSymbol: "EURC"
                )
                
                Divider().padding(.leading, 50)
                
                currencyRow(
                    symbol: "GBP",
                    icon: "sterlingsign.circle.fill",
                    color: .purple,
                    fiatValue: balance.totalValueGbp,
                    stablecoinValue: balance.totalValueUsdc * (balance.totalValueGbp / max(balance.totalValueUsd, 0.01)),
                    stablecoinSymbol: "~USDC"
                )
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func currencyRow(
        symbol: String,
        icon: String,
        color: Color,
        fiatValue: Double,
        stablecoinValue: Double,
        stablecoinSymbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.subheadline.weight(.medium))
                Text(stablecoinSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(fiatValue, currency: symbol))
                    .font(.subheadline.weight(.semibold))
                Text("\(formatAmount(stablecoinValue)) \(stablecoinSymbol)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Token Distribution
    
    private func tokenDistributionSection(_ balance: AggregatedBalanceResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Distribution")
                .font(.headline)
            
            VStack(spacing: 0) {
                ForEach(balance.tokenBreakdown) { token in
                    tokenRow(token, preferredFiat: balance.preferredFiat, preferredStablecoin: balance.preferredStablecoin)
                    
                    if token.id != balance.tokenBreakdown.last?.id {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func tokenRow(_ token: TokenBalanceInfo, preferredFiat: String, preferredStablecoin: String) -> some View {
        HStack(spacing: 12) {
            // Token icon
            ZStack {
                Circle()
                    .fill(tokenColor(token.tokenSymbol).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text(String(token.tokenSymbol.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(tokenColor(token.tokenSymbol))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(formatAmount(token.amount))
                        .font(.subheadline.weight(.semibold))
                    Text(token.tokenSymbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(token.blockchain.replacingOccurrences(of: "-", with: " "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                // Value in preferred fiat (USD, EUR, or GBP)
                let fiatValue: Double = {
                    switch preferredFiat {
                    case "EUR": return token.valueEur
                    case "GBP": return token.valueGbp
                    default: return token.valueUsd
                    }
                }()
                Text(formatCurrency(fiatValue, currency: preferredFiat))
                    .font(.subheadline.weight(.semibold))
                
                // Value in preferred stablecoin
                let stablecoinValue = preferredStablecoin == "EURC" ? token.valueEurc : token.valueUsdc
                Text("\(formatAmount(stablecoinValue)) \(preferredStablecoin)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Footer
    
    private func lastUpdatedFooter(_ balance: AggregatedBalanceResponse) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption2)
            Text("Updated \(balance.lastUpdated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
            
            Spacer()
            
            Text("Real-time prices")
                .font(.caption2)
            Image(systemName: "bolt.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
    
    // MARK: - Loading/Error/Empty Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading balances...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Failed to load balances")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await refreshBalance() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No balances yet")
                .font(.headline)
            
            Text("Create a wallet to see your balance distribution")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func refreshBalance() async {
        isLoading = true
        errorMessage = nil
        
        // Use walletViewModel to fetch balance (shared state)
        await walletViewModel.fetchAggregatedBalance()
        lastRefreshTime = Date()
        
        if walletViewModel.aggregatedBalance != nil {
            print("✅ [BalanceDistribution] Loaded balance: \(walletViewModel.aggregatedBalance?.totalInPreferredFiat ?? 0)")
        } else {
            print("⚠️ [BalanceDistribution] No balance data available")
        }
        
        isLoading = false
    }
    
    private func formatCurrency(_ value: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }
    
    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    private func tokenColor(_ symbol: String) -> Color {
        switch symbol.uppercased() {
        case "USDC": return .green
        case "EURC": return .blue
        case "ETH": return .purple
        case "MATIC": return .indigo
        case "ARC": return .orange
        default: return .gray
        }
    }
}

#Preview {
    BalanceDistributionView()
}
