import SwiftUI
import SwiftData

/// Swap tokens screen
struct SwapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var fromToken = Token.usdc
    @State private var toToken = Token.eth
    @State private var fromAmount: String = ""
    @State private var toAmount: String = ""
    @State private var exchangeRate: Double = 2500.0 // Example: 1 ETH = 2500 USDC
    @State private var isCalculating = false
    @State private var showingTokenPicker = false
    @State private var selectingFromToken = true
    @State private var slippage: Double = 0.5
    @State private var showingSettings = false
    @FocusState private var focusedField: Field?

    enum Field {
        case fromAmount, toAmount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // From Token Section
                        tokenInputCard(
                            title: "From",
                            token: $fromToken,
                            amount: $fromAmount,
                            field: .fromAmount,
                            isFrom: true
                        )

                        // Swap Button
                        swapButton

                        // To Token Section
                        tokenInputCard(
                            title: "To",
                            token: $toToken,
                            amount: $toAmount,
                            field: .toAmount,
                            isFrom: false
                        )

                        // Exchange Rate Info
                        if !fromAmount.isEmpty {
                            exchangeRateCard
                        }

                        // Swap Details
                        if isValidSwap {
                            swapDetailsCard
                        }

                        Spacer(minLength: 40)

                        // Review Button
                        reviewButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingTokenPicker) {
                TokenPickerSheet(
                    selectedToken: selectingFromToken ? $fromToken : $toToken,
                    excludeToken: selectingFromToken ? toToken : fromToken
                )
            }
            .sheet(isPresented: $showingSettings) {
                SwapSettingsSheet(slippage: $slippage)
            }
            .onChange(of: fromAmount) { _, newValue in
                calculateToAmount(from: newValue)
            }
        }
    }

    // MARK: - Token Input Card

    private func tokenInputCard(
        title: String,
        token: Binding<Token>,
        amount: Binding<String>,
        field: Field,
        isFrom: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Token Selector
                Button {
                    selectingFromToken = isFrom
                    showingTokenPicker = true
                } label: {
                    HStack {
                        Image(systemName: token.wrappedValue.icon)
                            .font(.title2)
                            .foregroundStyle(token.wrappedValue.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(token.wrappedValue.symbol)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(token.wrappedValue.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }

                // Amount Input
                HStack {
                    TextField("0.00", text: amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: field)
                        .font(.system(size: 32, weight: .bold))
                        .disabled(!isFrom)

                    if isFrom {
                        Button("MAX") {
                            // TODO: Set to max balance
                            amount.wrappedValue = "1000.00"
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Balance
                HStack {
                    Text("Balance:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("1,234.56 \(token.wrappedValue.symbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Swap Button

    private var swapButton: some View {
        Button {
            withAnimation {
                // Swap tokens and amounts
                let tempToken = fromToken
                fromToken = toToken
                toToken = tempToken

                let tempAmount = fromAmount
                fromAmount = toAmount
                toAmount = tempAmount
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up.arrow.down")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Exchange Rate Card

    private var exchangeRateCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Exchange Rate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if isCalculating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("1 \(fromToken.symbol) = \(String(format: "%.4f", exchangeRate)) \(toToken.symbol)")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Swap Details Card

    private var swapDetailsCard: some View {
        VStack(spacing: 12) {
            SwapDetailRow(title: "Slippage Tolerance", value: "\(String(format: "%.1f", slippage))%")
            Divider()
            SwapDetailRow(title: "Network Fee", value: "~$0.50")
            Divider()
            SwapDetailRow(title: "Protocol Fee", value: "~$0.25")
            Divider()
            SwapDetailRow(title: "Minimum Received", value: "\(calculateMinimumReceived()) \(toToken.symbol)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Review Button

    private var reviewButton: some View {
        Button {
            // TODO: Show review swap screen
        } label: {
            Text("Review Swap")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isValidSwap ? Color.orange : Color.gray)
                .cornerRadius(16)
        }
        .disabled(!isValidSwap)
    }

    // MARK: - Helper Methods

    private var isValidSwap: Bool {
        guard let amount = Double(fromAmount), amount > 0 else {
            return false
        }
        return fromToken != toToken
    }

    private func calculateToAmount(from fromValue: String) {
        guard let amount = Double(fromValue), amount > 0 else {
            toAmount = ""
            return
        }

        isCalculating = true

        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Calculate based on exchange rate
            let result = amount * exchangeRate
            toAmount = String(format: "%.6f", result)
            isCalculating = false
        }
    }

    private func calculateMinimumReceived() -> String {
        guard let amount = Double(toAmount), amount > 0 else {
            return "0"
        }

        let minimum = amount * (1 - slippage / 100)
        return String(format: "%.6f", minimum)
    }
}

// MARK: - Detail Row Component

struct SwapDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.bold())
        }
    }
}

// MARK: - Token Model

struct Token: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let name: String
    let icon: String
    let color: Color

    static let usdc = Token(symbol: "USDC", name: "USD Coin", icon: "dollarsign.circle.fill", color: .blue)
    static let eth = Token(symbol: "ETH", name: "Ethereum", icon: "e.circle.fill", color: .purple)
    static let matic = Token(symbol: "MATIC", name: "Polygon", icon: "m.circle.fill", color: .indigo)
    static let arb = Token(symbol: "ARB", name: "Arbitrum", icon: "a.circle.fill", color: .cyan)
    static let avax = Token(symbol: "AVAX", name: "Avalanche", icon: "mountain.2.fill", color: .red)

    static let allTokens = [usdc, eth, matic, arb, avax]
}

// MARK: - Token Picker Sheet

struct TokenPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedToken: Token
    let excludeToken: Token

    var body: some View {
        NavigationStack {
            List {
                ForEach(Token.allTokens.filter { $0 != excludeToken }) { token in
                    Button {
                        selectedToken = token
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: token.icon)
                                .font(.title2)
                                .foregroundStyle(token.color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(token.symbol)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(token.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if token == selectedToken {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Swap Settings Sheet

struct SwapSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var slippage: Double

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Slippage Tolerance: \(String(format: "%.1f", slippage))%")
                            .font(.subheadline)

                        Slider(value: $slippage, in: 0.1...5.0, step: 0.1)

                        HStack {
                            Text("0.1%")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("5.0%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Slippage Tolerance")
                } footer: {
                    Text("Your transaction will revert if the price changes unfavorably by more than this percentage.")
                }

                Section {
                    HStack {
                        Text("0.5%")
                        Spacer()
                        Button("Set") {
                            slippage = 0.5
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }

                    HStack {
                        Text("1.0%")
                        Spacer()
                        Button("Set") {
                            slippage = 1.0
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                } header: {
                    Text("Quick Presets")
                }
            }
            .navigationTitle("Swap Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SwapView()
}
