import SwiftUI
import SwiftData

// MARK: - Token Model for Send View

struct SendableToken: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let balance: Double
    let isVerified: Bool
    let iconName: String
    
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: NSNumber(value: balance)) ?? "0.00"
    }
    
    var hasBalance: Bool {
        balance > 0
    }
    
    static func == (lhs: SendableToken, rhs: SendableToken) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Transaction Category

enum TransactionCategory: String, CaseIterable, Identifiable {
    case none = "None"
    case food = "Food & Dining"
    case shopping = "Shopping"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case bills = "Bills & Utilities"
    case health = "Health"
    case education = "Education"
    case travel = "Travel"
    case gifts = "Gifts"
    case business = "Business"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "tag"
        case .food: return "fork.knife"
        case .shopping: return "bag"
        case .transport: return "car"
        case .entertainment: return "film"
        case .bills: return "doc.text"
        case .health: return "heart"
        case .education: return "book"
        case .travel: return "airplane"
        case .gifts: return "gift"
        case .business: return "briefcase"
        case .other: return "ellipsis.circle"
        }
    }
}

/// Send money screen with token selection and balance verification
struct SendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var walletViewModel: WalletViewModel
    @StateObject private var transactionViewModel: TransactionViewModel

    @State private var showingConfirmation = false
    @State private var showingScanner = false
    @State private var showingTokenSelector = false
    @State private var isSetup = false
    @FocusState private var focusedField: Field?
    
    // Token selection state
    @State private var availableTokens: [SendableToken] = []
    @State private var selectedToken: SendableToken?
    @State private var isLoadingTokens = true
    
    // Category selection
    @State private var selectedCategory: TransactionCategory = .none
    
    // Gas fee estimate (in token units)
    private let estimatedGasFee: Double = 0.01
    
    private let preselectedWallet: LocalWallet?

    init(modelContext: ModelContext, preselectedWallet: LocalWallet? = nil) {
        _walletViewModel = StateObject(wrappedValue: WalletViewModel(modelContext: modelContext))
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(modelContext: modelContext))
        self.preselectedWallet = preselectedWallet
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

                        // Token Selection
                        tokenSelectionSection

                        // Amount Input
                        amountSection
                        
                        // Balance Warning
                        if let token = selectedToken, !canSendAmount {
                            balanceWarningSection(token: token)
                        }

                        // Description (Optional)
                        descriptionSection
                        
                        // Category (Optional)
                        categorySection

                        // Network Section
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
            .sheet(isPresented: $showingTokenSelector) {
                TokenSelectorView(
                    tokens: availableTokens,
                    selectedToken: $selectedToken,
                    onSelect: { token in
                        selectToken(token)
                        showingTokenSelector = false
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
            .task {
                await setupViewModels()
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupViewModels() async {
        guard !isSetup else { return }
        
        print("🔧 [SendView] Setting up view models...")
        
        if let user = authViewModel.currentUser {
            await walletViewModel.setCurrentUser(user)
            await transactionViewModel.setCurrentUser(user)
            
            // Load wallets
            await walletViewModel.loadWallets()
            
            // If we have a preselected wallet, select it
            if let preselected = preselectedWallet {
                walletViewModel.selectWallet(preselected)
                await transactionViewModel.setCurrentWallet(preselected)
            } else if let primaryWallet = walletViewModel.primaryWallet {
                // Otherwise use primary wallet
                await transactionViewModel.setCurrentWallet(primaryWallet)
            }
            
            // Load available tokens with balances
            await loadAvailableTokens()
            
            print("✅ [SendView] Setup complete - wallet: \(walletViewModel.primaryWallet?.shortAddress ?? "none")")
        } else {
            print("⚠️ [SendView] No user found")
        }
        
        isSetup = true
    }
    
    private func loadAvailableTokens() async {
        isLoadingTokens = true
        
        var tokens: [SendableToken] = []
        
        do {
            // Fetch real balances from API
            let aggregatedBalance = try await APIClient.shared.getAggregatedBalance()
            
            // Group balances by normalized token symbol
            // API may return "USDC-TESTNET" or "USDC", normalize to base symbol
            var tokenBalances: [String: Double] = [:]
            for tokenInfo in aggregatedBalance.tokenBreakdown {
                let symbol = tokenInfo.tokenSymbol.uppercased()
                // Normalize token symbols - extract base symbol (USDC from USDC-TESTNET)
                let baseSymbol: String
                if symbol.contains("USDC") {
                    baseSymbol = "USDC"
                } else if symbol.contains("EURC") {
                    baseSymbol = "EURC"
                } else {
                    baseSymbol = symbol
                }
                tokenBalances[baseSymbol, default: 0] += tokenInfo.amount
                print("📊 [SendView] Token: \(symbol) -> \(baseSymbol), amount: \(tokenInfo.amount)")
            }
            
            // Create USDC token
            let usdcBalance = tokenBalances["USDC"] ?? 0.0
            tokens.append(SendableToken(
                id: "usdc",
                symbol: "USDC",
                name: "USD Coin",
                balance: usdcBalance,
                isVerified: true,
                iconName: "dollarsign.circle.fill"
            ))
            
            // Create EURC token
            let eurcBalance = tokenBalances["EURC"] ?? 0.0
            tokens.append(SendableToken(
                id: "eurc",
                symbol: "EURC",
                name: "Euro Coin",
                balance: eurcBalance,
                isVerified: true,
                iconName: "eurosign.circle.fill"
            ))
            
            print("✅ [SendView] Loaded token balances - USDC: \(usdcBalance), EURC: \(eurcBalance)")
            
        } catch {
            print("⚠️ [SendView] Failed to fetch balances, using wallet balance: \(error)")
            
            // Fallback to wallet balance
            let walletBalance = Double(walletViewModel.primaryWallet?.balance ?? "0") ?? 0.0
            
            tokens.append(SendableToken(
                id: "usdc",
                symbol: "USDC",
                name: "USD Coin",
                balance: walletBalance,
                isVerified: true,
                iconName: "dollarsign.circle.fill"
            ))
            
            tokens.append(SendableToken(
                id: "eurc",
                symbol: "EURC",
                name: "Euro Coin",
                balance: 0.0,
                isVerified: true,
                iconName: "eurosign.circle.fill"
            ))
        }
        
        availableTokens = tokens
        
        // Select user's preferred token or first with balance
        if let preferredStablecoin = authViewModel.currentUser?.preferredStablecoin,
           let preferred = tokens.first(where: { $0.symbol == preferredStablecoin }) {
            selectToken(preferred)
        } else if let firstWithBalance = tokens.first(where: { $0.hasBalance }) {
            selectToken(firstWithBalance)
        } else if let first = tokens.first {
            selectToken(first)
        }
        
        isLoadingTokens = false
    }
    
    private func selectToken(_ token: SendableToken) {
        selectedToken = token
        transactionViewModel.tokenSymbol = token.symbol
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

    // MARK: - Token Selection Section
    
    private var tokenSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token")
                .font(.headline)
            
            if isLoadingTokens {
                HStack {
                    ProgressView()
                    Text("Loading tokens...")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                Button {
                    showingTokenSelector = true
                } label: {
                    HStack {
                        if let token = selectedToken {
                            // Token icon
                            Image(systemName: token.iconName)
                                .font(.title2)
                                .foregroundStyle(token.symbol == "USDC" ? .green : .blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(token.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Text("(\(token.symbol))")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    
                                    if token.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Text("Balance: \(token.formattedBalance) \(token.symbol)")
                                    .font(.caption)
                                    .foregroundColor(token.hasBalance ? .secondary : .red)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select a token")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // No balance warning
                if let token = selectedToken, !token.hasBalance {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Send may not be executed because the token balance is 0!")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Amount")
                    .font(.headline)
                
                Spacer()
                
                // Max button
                if let token = selectedToken {
                    Button {
                        setMaxAmount()
                    } label: {
                        Text("Max: \(token.formattedBalance)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 12) {
                // Amount input
                HStack {
                    TextField("0.00", text: $transactionViewModel.amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)

                    if let token = selectedToken {
                        HStack(spacing: 4) {
                            Image(systemName: token.iconName)
                                .foregroundStyle(token.symbol == "USDC" ? .green : .blue)
                            Text(token.symbol)
                        }
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Quick amount buttons
                HStack(spacing: 12) {
                    QuickAmountButton(amount: "10", tokenSymbol: selectedToken?.symbol ?? "USDC") {
                        transactionViewModel.amount = "10"
                    }

                    QuickAmountButton(amount: "25", tokenSymbol: selectedToken?.symbol ?? "USDC") {
                        transactionViewModel.amount = "25"
                    }

                    QuickAmountButton(amount: "50", tokenSymbol: selectedToken?.symbol ?? "USDC") {
                        transactionViewModel.amount = "50"
                    }

                    QuickAmountButton(amount: "100", tokenSymbol: selectedToken?.symbol ?? "USDC") {
                        transactionViewModel.amount = "100"
                    }
                }
            }
        }
    }
    
    // MARK: - Balance Warning Section
    
    private func balanceWarningSection(token: SendableToken) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Insufficient balance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                
                let amountValue = parseAmount(transactionViewModel.amount) ?? 0
                let needed = amountValue - token.balance
                if needed > 0 {
                    Text("You need \(String(format: "%.2f", needed)) more \(token.symbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
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
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category (Optional)")
                .font(.headline)
            
            Menu {
                ForEach(TransactionCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        transactionViewModel.transactionCategory = category.rawValue
                    } label: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .foregroundStyle(.blue)
                    
                    Text(selectedCategory.rawValue)
                        .foregroundStyle(selectedCategory == .none ? .secondary : .primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
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

    // MARK: - Validation & Helpers
    
    /// Parse amount string handling both comma and period as decimal separators
    private func parseAmount(_ amountString: String) -> Double? {
        // Handle both comma and period as decimal separators
        let normalizedAmount = amountString.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedAmount)
    }
    
    private var canSendAmount: Bool {
        guard let token = selectedToken,
              let amountValue = parseAmount(transactionViewModel.amount) else {
            return true // Don't show warning if no amount entered
        }
        return amountValue <= token.balance
    }

    private var isFormValid: Bool {
        let validation = transactionViewModel.validateSendForm()
        guard validation.isValid else { return false }
        
        // Also check if we have sufficient balance
        guard let token = selectedToken else { return false }
        guard let amountValue = parseAmount(transactionViewModel.amount) else { return false }
        
        return amountValue > 0 && amountValue <= token.balance
    }
    
    private func setMaxAmount() {
        guard let token = selectedToken else { return }
        
        // Calculate max amount (balance - estimated gas fee)
        let maxAmount = max(0, token.balance - estimatedGasFee)
        
        // Format to 6 decimal places max
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        
        transactionViewModel.amount = formatter.string(from: NSNumber(value: maxAmount)) ?? "0.00"
    }
}

// MARK: - Token Selector View

struct TokenSelectorView: View {
    let tokens: [SendableToken]
    @Binding var selectedToken: SendableToken?
    let onSelect: (SendableToken) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var filterMode: TokenFilterMode = .verified
    
    enum TokenFilterMode: String, CaseIterable {
        case all = "All tokens"
        case verified = "Verified"
        case unverified = "Unverified"
    }
    
    var filteredTokens: [SendableToken] {
        var result = tokens
        
        // Apply filter
        switch filterMode {
        case .all:
            break
        case .verified:
            result = result.filter { $0.isVerified }
        case .unverified:
            result = result.filter { !$0.isVerified }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()
                
                // Filter tabs
                HStack(spacing: 12) {
                    ForEach(TokenFilterMode.allCases, id: \.self) { mode in
                        Button {
                            filterMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(filterMode == mode ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterMode == mode ? Color.blue.opacity(0.2) : Color.clear)
                                .foregroundStyle(filterMode == mode ? .blue : .secondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Token list
                List {
                    ForEach(filteredTokens) { token in
                        Button {
                            onSelect(token)
                        } label: {
                            HStack {
                                // Token icon
                                Image(systemName: token.iconName)
                                    .font(.title2)
                                    .foregroundStyle(token.symbol == "USDC" ? .green : .blue)
                                    .frame(width: 40, height: 40)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(token.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        Text("(\(token.symbol))")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        
                                        if token.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text(token.formattedBalance)
                                    .font(.body)
                                    .foregroundStyle(token.hasBalance ? .primary : .secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select a token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                    }
                }
            }
        }
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

@available(iOS 17.0, *)
struct SendView_Previews: PreviewProvider {
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
        
        SendView(modelContext: container.mainContext)
    }
}
