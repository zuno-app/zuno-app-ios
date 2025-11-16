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

    // SwiftData ModelContainer with our models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalUser.self,
            LocalWallet.self,
            LocalTransaction.self,
            CachedData.self,
            AppSettings.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Initialize AuthViewModel with modelContext
        let context = sharedModelContainer.mainContext
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .modelContainer(sharedModelContainer)
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication state routing
struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                HomeView(modelContext: modelContext)
            } else {
                WelcomeView()
            }
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

#Preview {
    let container = ModelContainer.preview
    let context = container.mainContext
    let authViewModel = AuthViewModel(modelContext: context)

    return RootView()
        .environmentObject(authViewModel)
        .modelContainer(container)
}
