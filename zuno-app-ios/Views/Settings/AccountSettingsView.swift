//
//  AccountSettingsView.swift
//  zuno-app-ios
//
//  Created on 2024-11-27.
//

import SwiftUI
import SwiftData
import AuthenticationServices

/// Account settings view for managing email, zuno tag, and authentication methods
struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        List {
            // Profile Section
            Section {
                NavigationLink {
                    EditZunoTagView()
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Label("@zuno Tag", systemImage: "at")
                        Spacer()
                        Text("@\(authViewModel.currentUser?.zunoTag ?? "")")
                            .foregroundStyle(.secondary)
                    }
                }
                
                NavigationLink {
                    EditEmailView()
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Label("Email", systemImage: "envelope")
                        Spacer()
                        Text(authViewModel.currentUser?.email ?? "Not set")
                            .foregroundStyle(.secondary)
                    }
                }
                
                NavigationLink {
                    EditDisplayNameView()
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Label("Display Name", systemImage: "person")
                        Spacer()
                        Text(authViewModel.currentUser?.displayName ?? "Not set")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Profile")
            } footer: {
                Text("Your @zuno tag and email must be unique. Changing them won't affect your wallet access.")
            }
            
            // Security Section
            Section {
                NavigationLink {
                    PasskeyManagementView()
                        .environmentObject(authViewModel)
                } label: {
                    Label("Manage Passkeys", systemImage: "key.fill")
                }
                
                NavigationLink {
                    BiometricSettingsView()
                } label: {
                    Label("Face ID / Touch ID", systemImage: "faceid")
                }
            } header: {
                Text("Security")
            } footer: {
                Text("You can add or remove passkeys and biometric authentication at any time without affecting your wallet access.")
            }
            
            // Info Section
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Your wallets are linked to your account ID, not your email or @zuno tag. You can safely change these without losing access to your funds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Edit Zuno Tag View

struct EditZunoTagView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var newZunoTag: String = ""
    @State private var isCheckingAvailability = false
    @State private var isTagAvailable: Bool? = nil
    @State private var validationMessage: String?
    @State private var showConfirmation = false
    @State private var isUpdating = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("@\(authViewModel.currentUser?.zunoTag ?? "")")
                        .fontWeight(.medium)
                }
            }
            
            Section {
                HStack {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("new_zuno_tag", text: $newZunoTag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: newZunoTag) { _, _ in
                            validateTag()
                            isTagAvailable = nil
                        }
                    
                    if isCheckingAvailability {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let available = isTagAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available ? .green : .red)
                    }
                }
                
                if let message = validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if isTagAvailable == false {
                    Text("This @zuno tag is already taken")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if isTagAvailable == true {
                    Text("This @zuno tag is available!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("New @zuno Tag")
            } footer: {
                Text("3-50 characters, lowercase letters, numbers, and underscores only")
            }
            
            Section {
                Button {
                    Task {
                        await checkAvailability()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isCheckingAvailability {
                            ProgressView()
                        } else {
                            Text("Check Availability")
                        }
                        Spacer()
                    }
                }
                .disabled(!isValidFormat || isCheckingAvailability)
            }
            
            Section {
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Update @zuno Tag")
                        }
                        Spacer()
                    }
                }
                .disabled(!canUpdate || isUpdating)
            }
        }
        .navigationTitle("Change @zuno Tag")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            newZunoTag = authViewModel.currentUser?.zunoTag ?? ""
        }
        .confirmationDialog("Confirm Change", isPresented: $showConfirmation) {
            Button("Change to @\(newZunoTag)") {
                Task {
                    await updateZunoTag()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to change your @zuno tag to @\(newZunoTag)? Your wallet access will not be affected.")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your @zuno tag has been updated to @\(newZunoTag)")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Failed to update @zuno tag")
        }
    }
    
    private var isValidFormat: Bool {
        let validation = authViewModel.validateZunoTag(newZunoTag)
        return validation.isValid && newZunoTag != authViewModel.currentUser?.zunoTag
    }
    
    private var canUpdate: Bool {
        isValidFormat && isTagAvailable == true
    }
    
    private func validateTag() {
        let validation = authViewModel.validateZunoTag(newZunoTag)
        validationMessage = validation.errorMessage
    }
    
    private func checkAvailability() async {
        guard isValidFormat else { return }
        
        isCheckingAvailability = true
        
        do {
            let available = try await APIClient.shared.checkZunoTagAvailability(newZunoTag)
            await MainActor.run {
                isTagAvailable = available
                isCheckingAvailability = false
            }
        } catch {
            await MainActor.run {
                isTagAvailable = nil
                isCheckingAvailability = false
                errorMessage = "Failed to check availability"
            }
        }
    }
    
    private func updateZunoTag() async {
        isUpdating = true
        
        // Note: Backend needs endpoint to update zuno_tag
        // For now, show error that this feature is coming soon
        await MainActor.run {
            isUpdating = false
            errorMessage = "Changing @zuno tag is coming soon. Your current tag will remain active."
            showErrorAlert = true
        }
    }
}

// MARK: - Edit Email View

struct EditEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var newEmail: String = ""
    @State private var isCheckingAvailability = false
    @State private var isEmailAvailable: Bool? = nil
    @State private var validationMessage: String?
    @State private var showConfirmation = false
    @State private var isUpdating = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(authViewModel.currentUser?.email ?? "Not set")
                        .fontWeight(.medium)
                }
            }
            
            Section {
                HStack {
                    TextField("new@email.com", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .onChange(of: newEmail) { _, _ in
                            validateEmail()
                            isEmailAvailable = nil
                        }
                    
                    if isCheckingAvailability {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let available = isEmailAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available ? .green : .red)
                    }
                }
                
                if let message = validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if isEmailAvailable == false {
                    Text("This email is already registered")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if isEmailAvailable == true {
                    Text("This email is available!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("New Email")
            }
            
            // Check Availability Button
            if isValidFormat && isEmailAvailable == nil {
                Section {
                    Button {
                        Task {
                            await checkAvailability()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isCheckingAvailability {
                                ProgressView()
                            } else {
                                Text("Check Availability")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isCheckingAvailability)
                }
            }
            
            Section {
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Update Email")
                        }
                        Spacer()
                    }
                }
                .disabled(!canUpdate || isUpdating)
            }
        }
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            newEmail = authViewModel.currentUser?.email ?? ""
        }
        .confirmationDialog("Confirm Change", isPresented: $showConfirmation) {
            Button("Change Email") {
                Task {
                    await updateEmail()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to change your email to \(newEmail)? Your wallet access will not be affected.")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your email has been updated to \(newEmail)")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Failed to update email")
        }
    }
    
    private var isValidFormat: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: newEmail) && newEmail != authViewModel.currentUser?.email
    }
    
    private var canUpdate: Bool {
        // Can update if email is empty (removing email) or if it's valid and available
        if newEmail.isEmpty {
            return true
        }
        return isValidFormat && isEmailAvailable == true
    }
    
    private func validateEmail() {
        if newEmail.isEmpty {
            validationMessage = nil
            return
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: newEmail) {
            validationMessage = "Please enter a valid email address"
        } else {
            validationMessage = nil
        }
    }
    
    private func checkAvailability() async {
        guard isValidFormat else { return }
        
        isCheckingAvailability = true
        
        do {
            let available = try await APIClient.shared.checkEmailAvailability(newEmail)
            await MainActor.run {
                isEmailAvailable = available
                isCheckingAvailability = false
            }
        } catch {
            await MainActor.run {
                isEmailAvailable = nil
                isCheckingAvailability = false
                print("⚠️ [EditEmail] Error checking availability: \(error)")
            }
        }
    }
    
    private func updateEmail() async {
        isUpdating = true
        
        await authViewModel.updateProfile(email: newEmail.isEmpty ? nil : newEmail)
        
        await MainActor.run {
            isUpdating = false
            if authViewModel.showError {
                errorMessage = authViewModel.errorMessage
                showErrorAlert = true
                authViewModel.clearError()
            } else {
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Edit Display Name View

struct EditDisplayNameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var newDisplayName: String = ""
    @State private var showConfirmation = false
    @State private var isUpdating = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(authViewModel.currentUser?.displayName ?? "Not set")
                        .fontWeight(.medium)
                }
            }
            
            Section {
                TextField("Your Name", text: $newDisplayName)
            } header: {
                Text("New Display Name")
            }
            
            Section {
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Update Display Name")
                        }
                        Spacer()
                    }
                }
                .disabled(newDisplayName == authViewModel.currentUser?.displayName || isUpdating)
            }
        }
        .navigationTitle("Change Display Name")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            newDisplayName = authViewModel.currentUser?.displayName ?? ""
        }
        .confirmationDialog("Confirm Change", isPresented: $showConfirmation) {
            Button("Update Name") {
                Task {
                    await updateDisplayName()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to change your display name?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your display name has been updated")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Failed to update display name")
        }
    }
    
    private func updateDisplayName() async {
        isUpdating = true
        
        await authViewModel.updateProfile(displayName: newDisplayName.isEmpty ? nil : newDisplayName)
        
        await MainActor.run {
            isUpdating = false
            if authViewModel.showError {
                errorMessage = authViewModel.errorMessage
                showErrorAlert = true
                authViewModel.clearError()
            } else {
                showSuccessAlert = true
            }
        }
    }
}
