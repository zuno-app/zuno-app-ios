//
//  SettingsView.swift
//  zuno-app-ios
//
//  Created on 11/24/25.
//

import SwiftUI
import SwiftData

/// Settings view
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // CRITICAL: Use @EnvironmentObject to share the same AuthViewModel instance
    // Using @StateObject would create a NEW instance that doesn't affect the app's auth state
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingLogoutConfirmation = false
    @State private var showingAbout = false
    
    init(modelContext: ModelContext) {
        // No longer creating a new AuthViewModel - using shared one from environment
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    NavigationLink {
                        AccountSettingsView()
                            .environmentObject(authViewModel)
                    } label: {
                        if let user = authViewModel.currentUser {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if let displayName = user.displayName {
                                        Text(displayName)
                                            .font(.headline)
                                    }
                                    Text("@\(user.zunoTag)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Security Section
                Section("Security") {
                    NavigationLink {
                        PasskeyManagementView()
                            .environmentObject(authViewModel)
                    } label: {
                        Label("Passkeys", systemImage: "key.fill")
                    }
                    
                    NavigationLink {
                        BiometricSettingsView()
                    } label: {
                        Label("Biometric Authentication", systemImage: "faceid")
                    }
                }
                
                // Preferences Section
                Section("Preferences") {
                    NavigationLink {
                        Text("Notification Settings")
                            .navigationTitle("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    
                    NavigationLink {
                        Text("Display Settings")
                            .navigationTitle("Display")
                    } label: {
                        Label("Display", systemImage: "paintbrush.fill")
                    }
                }
                
                // Support Section
                Section("Support") {
                    Button {
                        showingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    Link(destination: URL(string: "https://zuno.app/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://zuno.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    
                    Link(destination: URL(string: "https://zuno.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text("Version 1.0.0 (Build 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    Task {
                        await authViewModel.logout()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 40)
                    
                    // App Name
                    Text("Zuno Wallet")
                        .font(.title.bold())
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Description
                    Text("A secure, passwordless crypto wallet powered by passkeys and biometric authentication.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        AboutFeatureRow(icon: "key.fill", title: "Passwordless", description: "Secure authentication with passkeys")
                        AboutFeatureRow(icon: "faceid", title: "Biometric", description: "Face ID and Touch ID support")
                        AboutFeatureRow(icon: "network", title: "Multi-Chain", description: "Support for multiple blockchains")
                        AboutFeatureRow(icon: "lock.shield.fill", title: "Secure", description: "Your keys, your crypto")
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    // Copyright
                    Text("© 2025 Zuno. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
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

private struct AboutFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([LocalUser.self, LocalWallet.self, LocalTransaction.self, CachedData.self, AppSettings.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        
        SettingsView(modelContext: container.mainContext)
    }
}
