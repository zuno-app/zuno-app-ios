import SwiftUI
import SwiftData

/// Send money screen
struct SendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletViewModel: WalletViewModel
    @StateObject private var transactionViewModel: TransactionViewModel

    @State private var showingConfirmation = false
    @State private var showingScanner = false
    @FocusState private var focusedField: Field?

    init(modelContext: ModelContext) {
        _walletViewModel = StateObject(wrappedValue: WalletViewModel(modelContext: modelContext))
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(modelContext: modelContext))
    }

    enum Field {
        case recipient, amount, description
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Recipient Input
                        recipientSection

                        // Amount Input
                        amountSection

                        // Description (Optional)
                        descriptionSection

                        // Network Selection
                        networkSection

                        Spacer(minLength: 40)

                        // Continue Button
                        continueButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConfirmation) {
                ConfirmSendView(
                    transactionViewModel: transactionViewModel,
                    walletViewModel: walletViewModel,
                    onSuccess: {
                        dismiss()
                    }
                )
            }
            .alert("Error", isPresented: $transactionViewModel.showError) {
                Button("OK") {
                    transactionViewModel.clearError()
                }
            } message: {
                if let error = transactionViewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Recipient Section

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send To")
                .font(.headline)

            // Toggle between address and @zuno tag
            Picker("Recipient Type", selection: $transactionViewModel.useZunoTag) {
                Text("Address").tag(false)
                Text("@zuno Tag").tag(true)
            }
            .pickerStyle(.segmented)

            if transactionViewModel.useZunoTag {
                // @zuno tag input
                HStack {
                    Text("@")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField("username", text: $transactionViewModel.recipientZunoTag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .recipient)
                        .font(.body)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                // Address input
                HStack {
                    TextField("0x...", text: $transactionViewModel.recipientAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .recipient)
                        .font(.body)

                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.headline)

            VStack(spacing: 12) {
                // Amount input
                HStack {
                    TextField("0.00", text: $transactionViewModel.amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(transactionViewModel.tokenSymbol)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Quick amount buttons
                HStack(spacing: 12) {
                    QuickAmountButton(amount: "10", tokenSymbol: transactionViewModel.tokenSymbol) {
                        transactionViewModel.amount = "10"
                    }

                    QuickAmountButton(amount: "25", tokenSymbol: transactionViewModel.tokenSymbol) {
                        transactionViewModel.amount = "25"
                    }

                    QuickAmountButton(amount: "50", tokenSymbol: transactionViewModel.tokenSymbol) {
                        transactionViewModel.amount = "50"
                    }

                    QuickAmountButton(amount: "100", tokenSymbol: transactionViewModel.tokenSymbol) {
                        transactionViewModel.amount = "100"
                    }
                }
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description (Optional)")
                .font(.headline)

            TextField("What's this for?", text: $transactionViewModel.transactionDescription)
                .focused($focusedField, equals: .description)
                .font(.body)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.headline)

            if let wallet = walletViewModel.primaryWallet {
                HStack {
                    Image(systemName: "network")
                        .foregroundStyle(.blue)

                    Text(wallet.blockchainDisplayName)
                        .font(.body)

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            showingConfirmation = true
        } label: {
            Text("Review Transaction")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isFormValid ? Color.blue : Color.gray)
                .cornerRadius(16)
        }
        .disabled(!isFormValid)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let validation = transactionViewModel.validateSendForm()
        return validation.isValid
    }
}

// MARK: - Quick Amount Button

struct QuickAmountButton: View {
    let amount: String
    let tokenSymbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(amount)
                    .font(.headline)
                Text(tokenSymbol)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Preview

#Preview {
    SendView(modelContext: ModelContext(ModelContainer.preview))
}
