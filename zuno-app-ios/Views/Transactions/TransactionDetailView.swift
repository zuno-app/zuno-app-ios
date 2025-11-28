import SwiftUI
import SafariServices

/// Transaction detail/receipt view
struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let transaction: LocalTransaction

    @State private var showingShareSheet = false
    @State private var showCopiedToast = false
    @State private var showingSafari = false
    @State private var safariURL: URL?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Status Header
                    statusHeader

                    // Amount Display
                    amountDisplay

                    // Transaction Details Card
                    transactionDetailsCard

                    // Timeline (for pending/processing)
                    if transaction.status == .pending {
                        timelineCard
                    }

                    // Actions
                    actionsSection

                    Spacer(minLength: 40)
                }
                .padding()
            }

            // Copied Toast
            if showCopiedToast {
                copiedToast
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generateReceiptText()])
        }
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 80, height: 80)

                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(statusColor)
            }

            // Status text
            Text(statusText)
                .font(.title3.bold())
                .foregroundStyle(statusColor)

            // Timestamp
            Text(transaction.createdAt.formatted(date: .long, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text(transaction.isIncoming ? "Received" : "Sent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(transaction.isIncoming ? "+" : "-")\(transaction.amount) \(transaction.tokenSymbol)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(transaction.isIncoming ? .green : .primary)
        }
    }

    // MARK: - Transaction Details Card

    private var transactionDetailsCard: some View {
        VStack(spacing: 16) {
            // Transaction Type
            DetailRow(
                icon: transaction.transactionType.icon,
                title: "Type",
                value: transaction.transactionType.displayName
            )

            Divider()

            // From Address
            if let fromAddress = transaction.fromAddress {
                TappableDetailRow(
                    icon: "arrow.up.right",
                    title: "From",
                    value: formatAddress(fromAddress)
                ) {
                    copyToClipboard(fromAddress, label: "Address")
                }

                Divider()
            }

            // To Address / @zuno tag
            if let toZunoTag = transaction.toZunoTag {
                DetailRow(
                    icon: "person.circle",
                    title: "To",
                    value: "@\(toZunoTag)"
                )
            } else if let toAddress = transaction.toAddress {
                TappableDetailRow(
                    icon: "arrow.down.left",
                    title: "To",
                    value: formatAddress(toAddress)
                ) {
                    copyToClipboard(toAddress, label: "Address")
                }
            }

            Divider()

            // Transaction Hash
            if let txHash = transaction.blockchainTxHash {
                TappableDetailRow(
                    icon: "link",
                    title: "Transaction Hash",
                    value: formatAddress(txHash)
                ) {
                    copyToClipboard(txHash, label: "Transaction hash")
                }

                Divider()
            }

            // Fee
            if let fee = transaction.fee {
                DetailRow(
                    icon: "dollarsign.circle",
                    title: "Network Fee",
                    value: "\(fee) ETH"
                )

                Divider()
            }

            // Confirmations
            if let confirmations = transaction.confirmations {
                DetailRow(
                    icon: "checkmark.shield",
                    title: "Confirmations",
                    value: "\(confirmations)"
                )

                Divider()
            }

            // Description
            if let description = transaction.txDescription, !description.isEmpty {
                DetailRow(
                    icon: "text.bubble",
                    title: "Description",
                    value: description
                )

                Divider()
            }

            // Transaction ID
            TappableDetailRow(
                icon: "number",
                title: "Transaction ID",
                value: formatAddress(transaction.id)
            ) {
                copyToClipboard(transaction.id, label: "Transaction ID")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                TimelineItem(
                    icon: "checkmark.circle.fill",
                    title: "Initiated",
                    isCompleted: true
                )

                TimelineItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Processing",
                    isCompleted: false,
                    isActive: true
                )

                TimelineItem(
                    icon: "checkmark.circle",
                    title: "Confirmed",
                    isCompleted: false
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if let txHash = transaction.blockchainTxHash {
                Button {
                    openBlockExplorer(txHash: txHash)
                } label: {
                    Label("View on Block Explorer", systemImage: "arrow.up.forward.square")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            }

            Button {
                showingShareSheet = true
            } label: {
                Label("Share Receipt", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Copied to clipboard")
                    .font(.subheadline)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: showCopiedToast)
    }

    // MARK: - Helper Properties

    private var statusIcon: String {
        switch transaction.status {
        case .pending:
            return "clock"
        case .confirming:
            return "arrow.triangle.2.circlepath"
        case .confirmed:
            return transaction.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .pending, .confirming: return .orange
        case .confirmed: return .green
        case .failed, .cancelled: return .red
        }
    }

    private var statusBackgroundColor: Color {
        statusColor.opacity(0.15)
    }

    private var statusText: String {
        switch transaction.status {
        case .pending: return "Processing"
        case .confirming: return "Confirming"
        case .confirmed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    // MARK: - Helper Methods

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
        showCopiedToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func openBlockExplorer(txHash: String) {
        guard let url = getBlockExplorerURL(txHash: txHash) else { return }
        safariURL = url
        showingSafari = true
    }
    
    private func getBlockExplorerURL(txHash: String) -> URL? {
        // Determine blockchain from transaction or use default
        let blockchain = transaction.blockchain ?? "ARC_TESTNET"
        
        let explorerBase: String? = {
            switch blockchain.uppercased() {
            case let chain where chain.contains("ARC") && chain.contains("TESTNET"):
                // Arc Testnet explorer
                return "https://testnet.arcscan.app/tx"
            case let chain where chain.contains("ARC"):
                // Arc Mainnet explorer
                return "https://arcscan.app/tx"
            case let chain where chain.contains("ETH-SEPOLIA"):
                return "https://sepolia.etherscan.io/tx"
            case let chain where chain.contains("ETH"):
                return "https://etherscan.io/tx"
            case let chain where chain.contains("MATIC-AMOY"):
                return "https://amoy.polygonscan.com/tx"
            case let chain where chain.contains("MATIC"), let chain where chain.contains("POLYGON"):
                return "https://polygonscan.com/tx"
            case let chain where chain.contains("ARB-SEPOLIA"):
                return "https://sepolia.arbiscan.io/tx"
            case let chain where chain.contains("ARB"), let chain where chain.contains("ARBITRUM"):
                return "https://arbiscan.io/tx"
            case let chain where chain.contains("AVAX-FUJI"):
                return "https://testnet.snowtrace.io/tx"
            case let chain where chain.contains("AVAX"), let chain where chain.contains("AVALANCHE"):
                return "https://snowtrace.io/tx"
            case let chain where chain.contains("SOL-DEVNET"):
                return "https://explorer.solana.com/tx"
            case let chain where chain.contains("SOL"), let chain where chain.contains("SOLANA"):
                return "https://explorer.solana.com/tx"
            default:
                // Fallback to Arc testnet for this project
                return "https://testnet.arcscan.app/tx"
            }
        }()
        
        guard let base = explorerBase else { return nil }
        return URL(string: "\(base)/\(txHash)")
    }

    private func generateReceiptText() -> String {
        var text = """
        Zuno Wallet Receipt

        Amount: \(transaction.isIncoming ? "+" : "-")\(transaction.amount) \(transaction.tokenSymbol)
        Type: \(transaction.transactionType.displayName)
        Status: \(transaction.status.displayName)
        Date: \(transaction.createdAt.formatted(date: .long, time: .shortened))
        """

        if let toZunoTag = transaction.toZunoTag {
            text += "\nRecipient: @\(toZunoTag)"
        } else if let toAddress = transaction.toAddress {
            text += "\nTo: \(toAddress)"
        }

        if let txHash = transaction.blockchainTxHash {
            text += "\nTx Hash: \(txHash)"
        }

        return text
    }
}

// MARK: - Tappable Detail Row

struct TappableDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let icon: String
    let title: String
    let isCompleted: Bool
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(isCompleted || isActive ? .primary : .secondary)

            Spacer()

            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.15)
        } else if isActive {
            return .orange.opacity(0.15)
        } else {
            return Color(.tertiarySystemBackground)
        }
    }

    private var iconColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionDetailView(
            transaction: LocalTransaction(
                id: "tx_123456",
                transactionType: .send,
                status: .confirmed,
                amount: "100.00",
                tokenSymbol: "USDC",
                fromAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1",
                toAddress: nil,
                toZunoTag: "alice",
                blockchainTxHash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
                txDescription: "Coffee payment",
                fee: "0.0005",
                confirmations: 12
            )
        )
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = .systemBlue
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("Pending") {
    NavigationStack {
        TransactionDetailView(
            transaction: LocalTransaction(
                id: "tx_pending",
                transactionType: .send,
                status: .pending,
                amount: "50.00",
                tokenSymbol: "USDC",
                toZunoTag: "bob"
            )
        )
    }
}
