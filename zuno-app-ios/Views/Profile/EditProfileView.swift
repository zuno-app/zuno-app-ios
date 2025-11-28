//
//  EditProfileView.swift
//  zuno-app-ios
//
//  Created on 11/24/25.
//

import SwiftUI
import SwiftData

/// Edit user profile view
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let user: LocalUser
    
    @State private var displayName: String
    @State private var email: String
    @State private var defaultCurrency: String
    @State private var preferredNetwork: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    // Available options
    private let currencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD"]
    private let networks = ["ARC-TESTNET", "ARC-MAINNET", "POLYGON-AMOY", "ETHEREUM-SEPOLIA"]
    
    init(user: LocalUser, modelContext: ModelContext) {
        self.user = user
        _displayName = State(initialValue: user.displayName ?? "")
        _email = State(initialValue: user.email ?? "")
        _defaultCurrency = State(initialValue: user.defaultCurrency)
        _preferredNetwork = State(initialValue: user.preferredNetwork)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Preferences") {
                    Picker("Default Currency", selection: $defaultCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    Picker("Preferred Network", selection: $preferredNetwork) {
                        ForEach(networks, id: \.self) { network in
                            Text(networkDisplayName(network)).tag(network)
                        }
                    }
                }
                
                Section("Account") {
                    HStack {
                        Text("Zuno Tag")
                        Spacer()
                        Text("@\(user.zunoTag)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Member Since")
                        Spacer()
                        Text(user.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var hasChanges: Bool {
        displayName != (user.displayName ?? "") ||
        email != (user.email ?? "") ||
        defaultCurrency != user.defaultCurrency ||
        preferredNetwork != user.preferredNetwork
    }
    
    private func networkDisplayName(_ network: String) -> String {
        switch network {
        case "ARC-TESTNET": return "Arc Testnet"
        case "ARC-MAINNET": return "Arc Mainnet"
        case "POLYGON-AMOY": return "Polygon Amoy"
        case "ETHEREUM-SEPOLIA": return "Ethereum Sepolia"
        default: return network
        }
    }
    
    private func saveChanges() {
        isSaving = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                print("🔄 [EditProfile] Saving changes to backend...")
                
                // Update on backend via API FIRST
                let updatedUser = try await APIClient.shared.updateUser(
                    email: email.isEmpty ? nil : email,
                    displayName: displayName.isEmpty ? nil : displayName,
                    defaultCurrency: defaultCurrency,
                    preferredNetwork: preferredNetwork
                )
                
                print("✅ [EditProfile] Backend updated successfully")
                
                // Update user locally with response from backend
                user.displayName = updatedUser.displayName
                user.email = updatedUser.email
                user.defaultCurrency = updatedUser.defaultCurrency ?? defaultCurrency
                user.preferredNetwork = updatedUser.preferredNetwork ?? preferredNetwork
                user.updatedAt = Date()
                
                // Save to local database
                try modelContext.save()
                
                print("✅ [EditProfile] Local database updated successfully")
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
                
            } catch {
                print("❌ [EditProfile] Failed to save: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save changes: \(error.localizedDescription)"
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([LocalUser.self, LocalWallet.self, LocalTransaction.self, CachedData.self, AppSettings.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let user = LocalUser(
            id: "user_123",
            zunoTag: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            isVerified: true
        )
        
        EditProfileView(user: user, modelContext: container.mainContext)
    }
}
