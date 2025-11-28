//
//  PasskeyManagementView.swift
//  zuno-app-ios
//
//  Created on 2024-11-27.
//

import SwiftUI
import AuthenticationServices

/// View for managing passkeys - add new passkeys or view existing ones
struct PasskeyManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var showAddPasskeyConfirmation = false
    @State private var isAddingPasskey = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var passkeyName: String = ""
    
    var body: some View {
        List {
            // Current Passkey Info
            Section {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Primary Passkey")
                            .font(.headline)
                        Text("Registered with your account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Active Passkeys")
            } footer: {
                Text("Your passkey is securely stored on this device and protected by biometric authentication.")
            }
            
            // Add New Passkey
            Section {
                TextField("Passkey Name (e.g., Work iPhone)", text: $passkeyName)
                
                Button {
                    showAddPasskeyConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Passkey")
                    }
                }
                .disabled(isAddingPasskey)
            } header: {
                Text("Add Passkey")
            } footer: {
                Text("Add a passkey on another device to access your wallet from multiple devices.")
            }
            
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PasskeyInfoRow(icon: "lock.shield.fill", text: "Passkeys are more secure than passwords")
                    PasskeyInfoRow(icon: "faceid", text: "Protected by Face ID or Touch ID")
                    PasskeyInfoRow(icon: "icloud.fill", text: "Synced via iCloud Keychain")
                    PasskeyInfoRow(icon: "wallet.pass.fill", text: "Changing passkeys won't affect your wallets")
                }
                .padding(.vertical, 8)
            } header: {
                Text("About Passkeys")
            }
        }
        .navigationTitle("Passkeys")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Add New Passkey", isPresented: $showAddPasskeyConfirmation) {
            Button("Add Passkey") {
                Task {
                    await addNewPasskey()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will register a new passkey for your account. You'll need to authenticate with Face ID or Touch ID.")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {}
        } message: {
            Text("New passkey has been added successfully. You can now use it to sign in.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Failed to add passkey")
        }
    }
    
    private func addNewPasskey() async {
        isAddingPasskey = true
        
        // Get window for passkey UI
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            await MainActor.run {
                isAddingPasskey = false
                errorMessage = "Could not present passkey dialog"
                showErrorAlert = true
            }
            return
        }
        
        // Note: Adding additional passkeys requires backend support
        // For now, show info that this feature is coming
        await MainActor.run {
            isAddingPasskey = false
            errorMessage = "Adding additional passkeys is coming soon. Your current passkey remains active."
            showErrorAlert = true
        }
    }
}

// MARK: - Biometric Settings View

struct BiometricSettingsView: View {
    @State private var isBiometricEnabled = true
    @State private var showConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    private let biometricService = BiometricAuthService.shared
    
    var body: some View {
        List {
            // Biometric Status
            Section {
                HStack {
                    Image(systemName: biometricService.biometricType.icon)
                        .foregroundStyle(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(biometricService.biometricType == .faceID ? "Face ID" : "Touch ID")
                            .font(.headline)
                        Text(biometricService.biometricType == .none ? "Not available on this device" : "Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if biometricService.biometricType != .none {
                        Toggle("", isOn: $isBiometricEnabled)
                            .onChange(of: isBiometricEnabled) { _, newValue in
                                if !newValue {
                                    showConfirmation = true
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Quick Unlock")
            } footer: {
                Text("Use \(biometricService.biometricType == .faceID ? "Face ID" : "Touch ID") for quick access to your wallet. You can always use your passkey instead.")
            }
            
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PasskeyInfoRow(icon: "bolt.fill", text: "Faster access to your wallet")
                    PasskeyInfoRow(icon: "key.fill", text: "Passkey remains as backup")
                    PasskeyInfoRow(icon: "wallet.pass.fill", text: "Disabling won't affect your wallets")
                }
                .padding(.vertical, 8)
            } header: {
                Text("About Biometric Authentication")
            }
        }
        .navigationTitle("Biometrics")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Disable Biometric Unlock", isPresented: $showConfirmation) {
            Button("Disable", role: .destructive) {
                // Save preference
                UserDefaults.standard.set(false, forKey: "biometricEnabled")
                showSuccessAlert = true
            }
            Button("Cancel", role: .cancel) {
                isBiometricEnabled = true
            }
        } message: {
            Text("Are you sure you want to disable \(biometricService.biometricType == .faceID ? "Face ID" : "Touch ID")? You'll need to use your passkey to sign in.")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {}
        } message: {
            Text("Biometric authentication has been \(isBiometricEnabled ? "enabled" : "disabled").")
        }
        .onAppear {
            isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
            if !UserDefaults.standard.contains(key: "biometricEnabled") {
                isBiometricEnabled = true
            }
        }
    }
}

// MARK: - Helper Views

private struct PasskeyInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PasskeyManagementView()
    }
}
