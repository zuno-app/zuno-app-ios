//
//  zuno_app_iosApp.swift
//  zuno-app-ios
//
//  Created by Jose Erney Ospina on 15/11/25.
//

import SwiftUI
import SwiftData

@main
struct zuno_app_iosApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var walletViewModel: WalletViewModel  // Move to app level to persist
    @StateObject private var webSocketService = WebSocketService()  // Real-time updates

    // SwiftData ModelContainer with our models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalUser.self,
            LocalWallet.self,
            LocalTransaction.self,
            CachedData.self,
            AppSettings.self
        ])

        // Use default configuration which handles directory creation automatically
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [SwiftData] ModelContainer created successfully")
            return container
        } catch {
            print("❌ [SwiftData] Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Initialize ViewModels with modelContext
        let context = sharedModelContainer.mainContext
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: context))
        _walletViewModel = StateObject(wrappedValue: WalletViewModel(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(walletViewModel)  // Provide to all views
                .environmentObject(webSocketService)  // Real-time updates
                .modelContainer(sharedModelContainer)
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication state routing
struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel  // Access shared wallet state
    @Environment(\.modelContext) private var modelContext
    @State private var hasCheckedCredentials = false
    @State private var showBiometricPrompt = false
    @State private var showPasskeyLogin = false

    var body: some View {
        Group {
            if authViewModel.isLoading && !showBiometricPrompt && !showPasskeyLogin {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                if let user = authViewModel.currentUser {
                    // Use AuthenticatedView which owns the WalletViewModel
                    AuthenticatedView(user: user, modelContext: modelContext)
                } else {
                    // Authenticated but no user loaded - show loading
                    LoadingView()
                        .onAppear {
                            print("⚠️ [RootView] Authenticated but no user - reloading...")
                            Task {
                                await authViewModel.checkAuthStatus()
                            }
                        }
                }
            } else if showBiometricPrompt {
                // Show biometric unlock screen for returning users
                BiometricUnlockView(
                    onUnlock: {
                        print("🔓 [RootView] Biometric unlock successful - performing quick login")
                        Task {
                            await authViewModel.quickLogin()
                            if authViewModel.isAuthenticated {
                                showBiometricPrompt = false
                            }
                        }
                    },
                    onUsePasskey: {
                        // Show passkey login for stored account
                        print("🔑 [RootView] User chose passkey login")
                        showBiometricPrompt = false
                        showPasskeyLogin = true
                    },
                    onSwitchAccount: {
                        // Clear credentials and show welcome
                        print("🔄 [RootView] User chose to switch account")
                        Task {
                            await authViewModel.logout()
                        }
                        showBiometricPrompt = false
                        showPasskeyLogin = false
                    }
                )
            } else if showPasskeyLogin {
                // Show passkey login view
                PasskeyLoginView(
                    authViewModel: authViewModel,
                    onSuccess: {
                        print("✅ [RootView] Passkey login successful")
                        showPasskeyLogin = false
                    },
                    onCancel: {
                        print("❌ [RootView] Passkey login cancelled")
                        showPasskeyLogin = false
                        // Go back to biometric prompt if we have credentials
                        checkForReturningUserSync()
                    }
                )
            } else {
                WelcomeView()
                    .onAppear {
                        print("⚠️ [RootView] Showing WelcomeView - isAuthenticated: \(authViewModel.isAuthenticated), hasUser: \(authViewModel.currentUser != nil)")
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.currentUser?.id)
        .animation(.easeInOut(duration: 0.3), value: showBiometricPrompt)
        .animation(.easeInOut(duration: 0.3), value: showPasskeyLogin)
        .task {
            // On app launch, check if we have stored credentials
            // If yes, show biometric prompt instead of auto-login
            if !hasCheckedCredentials {
                hasCheckedCredentials = true
                await checkForReturningUser()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                // Successfully authenticated - hide login screens
                showBiometricPrompt = false
                showPasskeyLogin = false
            } else {
                // Logged out - reset state to show welcome screen
                print("🔓 [RootView] User logged out - resetting wallet and auth state")
                // Reset wallet state synchronously BEFORE view updates
                walletViewModel.resetStateSync()
                showBiometricPrompt = false
                showPasskeyLogin = false
                hasCheckedCredentials = true // Prevent re-checking credentials
            }
        }
    }
    
    private func checkForReturningUser() async {
        // Check if we have stored credentials
        let hasToken = KeychainManager.shared.exists(forKey: Config.KeychainKeys.accessToken)
        let hasUserID = KeychainManager.shared.exists(forKey: Config.KeychainKeys.userID)
        
        if hasToken && hasUserID {
            print("🔐 [RootView] Found stored credentials - showing biometric prompt")
            await MainActor.run {
                showBiometricPrompt = true
            }
        } else {
            print("⚠️ [RootView] No stored credentials - showing welcome screen")
            await MainActor.run {
                showBiometricPrompt = false
            }
        }
    }
    
    private func checkForReturningUserSync() {
        // Synchronous version for use in callbacks
        let hasToken = KeychainManager.shared.exists(forKey: Config.KeychainKeys.accessToken)
        let hasUserID = KeychainManager.shared.exists(forKey: Config.KeychainKeys.userID)
        
        if hasToken && hasUserID {
            print("🔐 [RootView] Found stored credentials - showing biometric prompt")
            showBiometricPrompt = true
        } else {
            print("⚠️ [RootView] No stored credentials - showing welcome screen")
            showBiometricPrompt = false
        }
    }
}

// MARK: - Authenticated View

/// View shown after successful authentication - uses shared WalletViewModel from environment
struct AuthenticatedView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel  // Use from environment
    @EnvironmentObject private var webSocketService: WebSocketService  // Real-time updates
    let user: LocalUser
    let modelContext: ModelContext
    
    @State private var hasLoadedInitially = false
    @State private var walletCount: Int = 0  // Track wallet count for view updates
    
    init(user: LocalUser, modelContext: ModelContext) {
        self.user = user
        self.modelContext = modelContext
    }
    
    /// Computed property to determine which view to show
    private var shouldShowHome: Bool {
        // Show home if we have wallets OR wallet creation just completed
        !walletViewModel.wallets.isEmpty || walletViewModel.walletCreationComplete
    }
    
    private var shouldShowOnboarding: Bool {
        // Only show onboarding if:
        // 1. No wallets exist
        // 2. We've checked for wallets (not still loading)
        // 3. Wallet creation is NOT in progress
        // 4. Wallet creation has NOT just completed
        walletViewModel.wallets.isEmpty && 
        walletViewModel.hasCheckedWallets && 
        !walletViewModel.walletCreationComplete &&
        !walletViewModel.isCreatingWallet
    }
    
    var body: some View {
        Group {
            // Show loading only on initial load, not during wallet creation
            if walletViewModel.isLoading && !walletViewModel.hasCheckedWallets && !hasLoadedInitially && !walletViewModel.isCreatingWallet {
                LoadingView()
                    .onAppear {
                        print("⏳ [AuthenticatedView] Loading wallets for user: \(user.zunoTag)")
                    }
            }
            // Show home if we have wallets - CHECK THIS FIRST
            else if shouldShowHome {
                HomeView(modelContext: modelContext)
                    .id(user.id)
                    .onAppear {
                        print("✅ [AuthenticatedView] HomeView appeared for user: \(user.zunoTag) with \(walletViewModel.wallets.count) wallets")
                    }
            }
            // Check if user needs onboarding (no wallets) - only after loading is complete
            else if shouldShowOnboarding {
                WalletOnboardingView(
                    authViewModel: authViewModel,
                    walletViewModel: walletViewModel
                )
                .onAppear {
                    print("🎯 [AuthenticatedView] Showing onboarding - user has no wallets, isCreating=\(walletViewModel.isCreatingWallet), creationComplete=\(walletViewModel.walletCreationComplete)")
                }
            }
            // During wallet creation, keep showing onboarding (don't switch to loading)
            else if walletViewModel.isCreatingWallet {
                WalletOnboardingView(
                    authViewModel: authViewModel,
                    walletViewModel: walletViewModel
                )
                .onAppear {
                    print("🔄 [AuthenticatedView] Showing onboarding during wallet creation")
                }
            }
            // Initial state - show loading while we fetch
            else {
                LoadingView()
            }
        }
        .onChange(of: walletViewModel.wallets.count) { oldCount, newCount in
            print("🔄 [AuthenticatedView] Wallet count changed: \(oldCount) -> \(newCount)")
            walletCount = newCount
        }
        .onChange(of: walletViewModel.isCreatingWallet) { _, isCreating in
            print("🔄 [AuthenticatedView] isCreatingWallet changed to: \(isCreating), wallets.count=\(walletViewModel.wallets.count)")
        }
        .onChange(of: walletViewModel.walletCreationComplete) { _, complete in
            print("🚀 [AuthenticatedView] walletCreationComplete changed to: \(complete)")
            // Force view update when creation completes
            if complete {
                walletCount = walletViewModel.wallets.count
            }
        }
        .task {
            // Only load wallets once on initial appear
            guard !hasLoadedInitially else { return }
            hasLoadedInitially = true
            
            // Load wallets when view appears
            print("🔄 [AuthenticatedView] Starting wallet load for user: \(user.zunoTag)")
            await walletViewModel.setCurrentUser(user)
            await walletViewModel.refreshWallets()
            walletCount = walletViewModel.wallets.count
            print("✅ [AuthenticatedView] Wallet load complete. Found \(walletViewModel.wallets.count) wallets")
            
            // Connect WebSocket for real-time updates
            connectWebSocket()
        }
        .onReceive(webSocketService.transactionEvents) { event in
            handleTransactionEvent(event)
        }
        .onReceive(webSocketService.balanceEvents) { _ in
            // Refresh balance when we receive an update
            Task {
                await walletViewModel.fetchAggregatedBalance()
            }
        }
        .onDisappear {
            webSocketService.disconnect()
        }
    }
    
    // MARK: - WebSocket Integration
    
    private func connectWebSocket() {
        guard let token = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.accessToken) else {
            print("⚠️ [AuthenticatedView] No auth token for WebSocket")
            return
        }
        
        print("🔌 [AuthenticatedView] Connecting WebSocket...")
        webSocketService.connect(authToken: token)
        
        // Subscribe to wallet updates after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let walletIds = self.walletViewModel.wallets.map { $0.id }
            if !walletIds.isEmpty {
                print("📡 [AuthenticatedView] Subscribing to \(walletIds.count) wallets")
                self.webSocketService.subscribeToWallets(walletIds)
            }
        }
    }
    
    private func handleTransactionEvent(_ event: TransactionEvent) {
        print("💰 [AuthenticatedView] Transaction event: \(event.transactionType) \(event.amount) \(event.tokenSymbol)")
        
        // Post notification for HomeView to show alert
        NotificationCenter.default.post(name: .transactionReceived, object: event)
        
        // Refresh data
        Task {
            await walletViewModel.fetchAggregatedBalance()
        }
    }
}

// MARK: - Biometric Unlock View

struct BiometricUnlockView: View {
    let onUnlock: () -> Void
    let onUsePasskey: () -> Void
    let onSwitchAccount: () -> Void
    
    @State private var isAuthenticating = false
    @State private var authFailed = false
    @State private var errorMessage: String?
    @State private var storedZunoTag: String = ""
    @State private var hasTriedOnce = false
    
    private let biometricService = BiometricAuthService.shared
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // App Icon
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                Text("Zuno Wallet")
                    .font(.largeTitle.bold())
                
                // Show stored username
                if !storedZunoTag.isEmpty {
                    Text("Welcome back, @\(storedZunoTag)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unlock to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Error message
                if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }
                
                // Show different UI based on auth state
                if authFailed {
                    // After failure, show both options prominently
                    VStack(spacing: 16) {
                        // Try Face ID Again
                        Button {
                            Task {
                                await authenticateWithBiometrics()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if isAuthenticating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: biometricService.biometricType == .faceID ? "faceid" : "touchid")
                                        .font(.title2)
                                }
                                Text("Try \(biometricService.biometricType == .faceID ? "Face ID" : "Touch ID") Again")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isAuthenticating ? Color.gray : Color.blue)
                            .cornerRadius(16)
                        }
                        .disabled(isAuthenticating)
                        
                        // Login with Passkey - prominent button
                        Button {
                            onUsePasskey()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "key.fill")
                                    .font(.title2)
                                Text("Login with Passkey")
                                    .font(.headline)
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        // Switch Account option
                        Button {
                            onSwitchAccount()
                        } label: {
                            Text("Use Different Account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                } else {
                    // Initial state - show biometric button
                    VStack(spacing: 16) {
                        // Biometric Button
                        Button {
                            Task {
                                await authenticateWithBiometrics()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if isAuthenticating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: biometricService.biometricType == .faceID ? "faceid" : "touchid")
                                        .font(.title2)
                                }
                                Text(biometricService.biometricType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isAuthenticating ? Color.gray : Color.blue)
                            .cornerRadius(16)
                        }
                        .disabled(isAuthenticating)
                        
                        // Use Passkey option
                        Button {
                            onUsePasskey()
                        } label: {
                            Text("Use Passkey Instead")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .padding(.top, 8)
                        
                        // Switch Account option
                        Button {
                            onSwitchAccount()
                        } label: {
                            Text("Use Different Account")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Load stored zuno tag
            if let tag = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.zunoTag) {
                storedZunoTag = tag
            }
            
            // Auto-trigger biometrics only once on first appear
            if !hasTriedOnce {
                hasTriedOnce = true
                Task {
                    // Small delay to let the view appear
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await authenticateWithBiometrics()
                }
            }
        }
    }
    
    private func authenticateWithBiometrics() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        errorMessage = nil
        
        do {
            let success = try await biometricService.authenticate()
            if success {
                print("✅ [BiometricUnlock] Biometric authentication successful")
                await MainActor.run {
                    onUnlock()
                }
            } else {
                await MainActor.run {
                    authFailed = true
                    errorMessage = "Authentication failed"
                }
            }
        } catch {
            print("❌ [BiometricUnlock] Biometric error: \(error)")
            await MainActor.run {
                authFailed = true
                // Check if it's a simulator or biometrics not available
                if biometricService.biometricType == .none {
                    errorMessage = "Biometrics not available on this device"
                } else {
                    errorMessage = "Face ID failed or was canceled"
                }
            }
        }
        
        await MainActor.run {
            isAuthenticating = false
        }
    }
}

// MARK: - Passkey Login View

struct PasskeyLoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var zunoTag: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Icon
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Login with Passkey")
                        .font(.title2.bold())
                    
                    Text("Enter your @zuno tag to login")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Zuno Tag Input
                    HStack {
                        Text("@")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        TextField("username", text: $zunoTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    
                    // Error message
                    if authViewModel.showError, let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // Login Button
                    Button {
                        Task {
                            await loginWithPasskey()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "key.fill")
                                Text("Login")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(zunoTag.count >= 3 && !isLoading ? Color.blue : Color.gray)
                        .cornerRadius(16)
                    }
                    .disabled(zunoTag.count < 3 || isLoading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill with stored zuno tag if available
            if let tag = try? KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.zunoTag) {
                zunoTag = tag
            }
        }
    }
    
    private func loginWithPasskey() async {
        guard zunoTag.count >= 3 else { return }
        
        isLoading = true
        authViewModel.clearError()
        
        // Get the window for passkey presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            isLoading = false
            return
        }
        
        await authViewModel.login(zunoTag: zunoTag, window: window)
        
        isLoading = false
        
        if authViewModel.isAuthenticated {
            onSuccess()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Zuno Wallet")
                    .font(.title.bold())

                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct RootView_Previews: PreviewProvider {
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
        let context = container.mainContext
        let authViewModel = AuthViewModel(modelContext: context)
        let walletViewModel = WalletViewModel(modelContext: context)

        RootView()
            .environmentObject(authViewModel)
            .environmentObject(walletViewModel)
            .modelContainer(container)
    }
}
