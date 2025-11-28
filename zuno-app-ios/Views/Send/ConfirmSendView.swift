import SwiftUI
import SwiftData

/// Confirm send transaction screen
struct ConfirmSendView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var transactionViewModel: TransactionViewModel
    @ObservedObject var walletViewModel: WalletViewModel

    let onSuccess: () -> Void

    @State private var isSending = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    confirmationView
                }
            }
            .navigationTitle("Confirm Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSending && !showSuccess {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Display
                amountDisplay

                // Transaction Details
                transactionDetailsCard

                // Warning
                warningCard

                Spacer(minLength: 40)

                // Confirm Button
                confirmButton
            }
            .padding()
        }
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(transactionViewModel.formatAmount(
                transactionViewModel.amount,
                symbol: transactionViewModel.tokenSymbol
            ))
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(.primary)

            Text("You're sending")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Transaction Details Card

    private var transactionDetailsCard: some View {
        VStack(spacing: 16) {
            DetailRow(
                icon: "person.circle",
                title: "To",
                value: recipientDisplay
            )

            Divider()

            if let wallet = walletViewModel.primaryWallet {
                DetailRow(
                    icon: "network",
                    title: "Network",
                    value: wallet.blockchainDisplayName
                )

                Divider()

                DetailRow(
                    icon: "wallet.pass",
                    title: "From",
                    value: wallet.shortAddress
                )
            }

            if !transactionViewModel.transactionDescription.isEmpty {
                Divider()

                DetailRow(
                    icon: "text.bubble",
                    title: "Description",
                    value: transactionViewModel.transactionDescription
                )
            }
            
            if !transactionViewModel.transactionCategory.isEmpty && transactionViewModel.transactionCategory != "None" {
                Divider()

                DetailRow(
                    icon: "tag",
                    title: "Category",
                    value: transactionViewModel.transactionCategory
                )
            }

            Divider()

            DetailRow(
                icon: "clock",
                title: "Estimated Time",
                value: "~30 seconds"
            )

            Divider()

            DetailRow(
                icon: "dollarsign.circle",
                title: "Network Fee",
                value: "~$0.05"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Warning Card

    private var warningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Verify Recipient")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("Double check the recipient address. Transactions cannot be reversed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            Task {
                await sendTransaction()
            }
        } label: {
            HStack {
                if isSending {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Confirm & Send")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isSending ? Color.gray : Color.blue)
            .cornerRadius(16)
        }
        .disabled(isSending)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }

            Text("Transaction Sent!")
                .font(.title.bold())

            Text("Your transaction has been submitted to the network")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Done Button
            Button {
                onSuccess()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helper Properties

    private var recipientDisplay: String {
        if transactionViewModel.useZunoTag {
            return "@\(transactionViewModel.recipientZunoTag)"
        } else {
            let address = transactionViewModel.recipientAddress
            if address.count > 10 {
                return "\(address.prefix(6))...\(address.suffix(4))"
            }
            return address
        }
    }

    // MARK: - Send Transaction

    private func sendTransaction() async {
        // Prevent double-tap by checking if already sending
        guard !isSending else {
            print("⚠️ [ConfirmSendView] Already sending, ignoring duplicate tap")
            return
        }
        
        guard let wallet = walletViewModel.primaryWallet else { return }

        // Set isSending IMMEDIATELY before any async work
        isSending = true
        print("🔒 [ConfirmSendView] Transaction started - button disabled")

        let success = await transactionViewModel.sendTransaction(blockchain: wallet.blockchain)

        if success {
            print("✅ [ConfirmSendView] Transaction successful - showing success view")
            showSuccess = true
            
            // Refresh balance and transactions immediately after success
            Task {
                await walletViewModel.fetchAggregatedBalance()
            }
        } else {
            // Only reset isSending if transaction failed (to allow retry)
            print("❌ [ConfirmSendView] Transaction failed - allowing retry")
            isSending = false
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
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
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct ConfirmSendView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            LocalUser.self,
            LocalWallet.self,
            LocalTransaction.self,
            CachedData.self,
            AppSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = container.mainContext
        let transactionViewModel = TransactionViewModel(modelContext: modelContext)
        let walletViewModel = WalletViewModel(modelContext: modelContext)

        // Setup preview data
        transactionViewModel.amount = "100"
        transactionViewModel.tokenSymbol = "USDC"
        transactionViewModel.recipientZunoTag = "alice"
        transactionViewModel.useZunoTag = true

        return ConfirmSendView(
            transactionViewModel: transactionViewModel,
            walletViewModel: walletViewModel,
            onSuccess: {}
        )
    }
}
