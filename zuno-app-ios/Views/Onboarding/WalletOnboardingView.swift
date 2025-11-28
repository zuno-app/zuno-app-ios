//
//  WalletOnboardingView.swift
//  zuno-app-ios
//
//  Created on 2024-11-24.
//

import SwiftUI
import SwiftData

// MARK: - Network Configuration

struct NetworkInfo: Identifiable {
    let id: String
    let displayName: String
    let isSupported: Bool
    
    static let allNetworks: [NetworkInfo] = [
        NetworkInfo(id: "ARC-TESTNET", displayName: "Arc Testnet", isSupported: true),
        NetworkInfo(id: "ETHEREUM-SEPOLIA", displayName: "Ethereum Sepolia", isSupported: false),
        NetworkInfo(id: "POLYGON-AMOY", displayName: "Polygon Amoy", isSupported: false)
    ]
    
    static let supportedNetworks: [NetworkInfo] = allNetworks.filter { $0.isSupported }
    
    static func isNetworkSupported(_ networkId: String) -> Bool {
        allNetworks.first { $0.id == networkId }?.isSupported ?? false
    }
    
    static func getDisplayName(_ networkId: String) -> String {
        allNetworks.first { $0.id == networkId }?.displayName ?? networkId
    }
}

// MARK: - WalletOnboardingView

struct WalletOnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var walletViewModel: WalletViewModel
    
    @State private var selectedCurrency: String = "USDC"
    @State private var selectedNetwork: String = "ARC-TESTNET"
    @State private var walletName: String = "My USDC Wallet"
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUnsupportedNetworkAlert = false
    @State private var isProcessing = false
    
    @Environment(\.dismiss) private var dismiss
    
    let currencies = ["USDC", "EURC"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection
            
            Spacer()
            
            // Configuration Form
            configurationForm
            
            Spacer()
            
            // Create Wallet Button
            createButton
        }
        .onAppear {
            initializeFromUserPreferences()
        }
        .onChange(of: selectedCurrency) { _, newCurrency in
            updateWalletName(for: newCurrency)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Network Not Supported", isPresented: $showUnsupportedNetworkAlert) {
            Button("OK") {
                // Reset to supported network
                selectedNetwork = "ARC-TESTNET"
            }
        } message: {
            Text("The selected network is not supported yet.\n\nSupported networks:\n• Arc Testnet\n\nPlease select Arc Testnet to continue.")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Setup Your Wallet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose your preferred stablecoin and network to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    private var configurationForm: some View {
        VStack(spacing: 20) {
            // Wallet Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.headline)
                
                TextField("My \(selectedCurrency) Wallet", text: $walletName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                    .disabled(isProcessing || walletViewModel.isCreatingWallet)
            }
            
            // Currency Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Stablecoin")
                    .font(.headline)
                
                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(isProcessing || walletViewModel.isCreatingWallet)
            }
            
            // Network Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Network")
                    .font(.headline)
                
                Picker("Network", selection: $selectedNetwork) {
                    ForEach(NetworkInfo.allNetworks) { network in
                        HStack {
                            Text(network.displayName)
                            if !network.isSupported {
                                Text("(Coming Soon)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(network.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(isProcessing || walletViewModel.isCreatingWallet)
            }
            
            // Info Card
            infoCard
        }
        .padding(.horizontal)
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("About Your Wallet")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Each wallet is secured by your passkey")
                Text("• You can create multiple wallets")
                Text("• Change preferences later in settings")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var createButton: some View {
        Button(action: handleCreateWallet) {
            HStack {
                if isProcessing || walletViewModel.isCreatingWallet {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isProcessing || walletViewModel.isCreatingWallet ? "Creating Wallet..." : "Create My Wallet")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreateWallet ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreateWallet)
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties
    
    private var canCreateWallet: Bool {
        !walletName.isEmpty && !isProcessing && !walletViewModel.isCreatingWallet
    }
    
    // MARK: - Methods
    
    private func initializeFromUserPreferences() {
        // Only initialize if not already processing
        guard !isProcessing && !walletViewModel.isCreatingWallet else {
            print("🎯 [WalletOnboarding] Skipping init - already processing")
            return
        }
        
        let savedCurrency = authViewModel.currentUser?.defaultCurrency ?? ""
        let savedNetwork = authViewModel.currentUser?.preferredNetwork ?? ""
        
        if !savedCurrency.isEmpty && currencies.contains(savedCurrency) {
            selectedCurrency = savedCurrency
        }
        
        if !savedNetwork.isEmpty {
            selectedNetwork = savedNetwork
        }
        
        walletName = "My \(selectedCurrency) Wallet"
        
        print("🎯 [WalletOnboarding] Initialized: currency=\(selectedCurrency), network=\(selectedNetwork)")
    }
    
    private func updateWalletName(for currency: String) {
        if walletName.hasPrefix("My ") && walletName.hasSuffix(" Wallet") {
            walletName = "My \(currency) Wallet"
        }
    }
    
    private func handleCreateWallet() {
        // Check if network is supported
        guard NetworkInfo.isNetworkSupported(selectedNetwork) else {
            showUnsupportedNetworkAlert = true
            return
        }
        
        // Prevent double-clicks
        guard canCreateWallet else {
            print("⚠️ [WalletOnboarding] Cannot create wallet - button disabled")
            return
        }
        
        // Set processing flag immediately
        isProcessing = true
        
        // Capture current values
        let currency = selectedCurrency
        let network = selectedNetwork
        let name = walletName
        
        print("🌐 [WalletOnboarding] Starting wallet creation: \(name) on \(network) with \(currency)")
        
        Task {
            await createWalletAsync(currency: currency, network: network, name: name)
        }
    }
    
    private func createWalletAsync(currency: String, network: String, name: String) async {
        // Map stablecoin to fiat currency for display
        let fiatCurrency = currency == "EURC" ? "EUR" : "USD"
        
        print("🔧 [WalletOnboarding] Saving preferences: fiat=\(fiatCurrency), stablecoin=\(currency), network=\(network)")
        
        // Save user preferences - currency is fiat (USD/EUR), stablecoin is USDC/EURC
        await authViewModel.updateProfile(
            defaultCurrency: fiatCurrency,
            preferredNetwork: network,
            preferredStablecoin: currency
        )
        
        print("🌐 [WalletOnboarding] Creating wallet: \(name)")
        
        // Create the wallet - this will update walletViewModel.wallets internally
        await walletViewModel.createWallet(
            blockchain: network,
            name: name
        )
        
        // Small delay to ensure @Published properties have propagated
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check result - walletViewModel.wallets should be updated by createWallet
        await MainActor.run {
            print("📊 [WalletOnboarding] Checking result: wallets.count=\(walletViewModel.wallets.count), error=\(walletViewModel.errorMessage ?? "none")")
            
            if walletViewModel.wallets.count > 0 {
                print("✅ [WalletOnboarding] Wallet created successfully! Count: \(walletViewModel.wallets.count)")
                // Reset processing flag - view will automatically transition to HomeView
                isProcessing = false
            } else if let error = walletViewModel.errorMessage {
                print("❌ [WalletOnboarding] Error: \(error)")
                errorMessage = error
                showError = true
                isProcessing = false
            } else {
                print("⚠️ [WalletOnboarding] Unknown state - no wallets and no error, retrying load...")
                // Try loading wallets one more time
                Task {
                    await walletViewModel.loadWallets()
                    await MainActor.run {
                        if walletViewModel.wallets.count > 0 {
                            print("✅ [WalletOnboarding] Wallet found after retry!")
                            isProcessing = false
                        } else {
                            print("❌ [WalletOnboarding] Still no wallets after retry")
                            errorMessage = "Wallet creation may have succeeded but couldn't verify. Please restart the app."
                            showError = true
                            isProcessing = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([
        LocalUser.self,
        LocalWallet.self,
        LocalTransaction.self,
        CachedData.self,
        AppSettings.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
    let context = container.mainContext
    
    let authVM = AuthViewModel(modelContext: context)
    let walletVM = WalletViewModel(modelContext: context)
    
    return WalletOnboardingView(
        authViewModel: authVM,
        walletViewModel: walletVM
    )
}
