//
//  UserProfileView.swift
//  zuno-app-ios
//
//  Created on 11/21/25.
//

import SwiftUI
import SwiftData

/// User profile view - separate from settings
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    let user: LocalUser
    let walletCount: Int
    let totalBalance: String
    let modelContext: ModelContext
    
    @State private var showingEditProfile = false
    
    init(user: LocalUser, walletCount: Int, totalBalance: String, modelContext: ModelContext) {
        self.user = user
        self.walletCount = walletCount
        self.totalBalance = totalBalance
        self.modelContext = modelContext
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Cards
                    statsSection
                    
                    // Account Info
                    accountInfoSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditProfile = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(user: user, modelContext: modelContext)
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text(user.displayName?.prefix(1).uppercased() ?? 
                     user.zunoTag.prefix(1).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10)
            
            // Name and Tag
            VStack(spacing: 4) {
                if let displayName = user.displayName {
                    Text(displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                
                HStack(spacing: 4) {
                    Text("@\(user.zunoTag)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        UIPasteboard.general.string = "@\(user.zunoTag)"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            // Verification Badge
            if user.isVerified {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                    Text("Verified Account")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Wallets",
                value: "\(walletCount)",
                icon: "wallet.pass.fill",
                color: .blue
            )
            
            StatCard(
                title: "Balance",
                value: totalBalance,
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Network",
                value: user.preferredNetwork,
                icon: "network",
                color: .purple
            )
        }
    }
    
    // MARK: - Account Info Section
    
    private var accountInfoSection: some View {
        VStack(spacing: 0) {
            if let email = user.email {
                InfoRowView(
                    icon: "envelope.fill",
                    title: "Email",
                    value: email,
                    color: .blue
                )
                Divider().padding(.leading, 50)
            }
            
            InfoRowView(
                icon: "calendar",
                title: "Member Since",
                value: user.createdAt.formatted(date: .abbreviated, time: .omitted),
                color: .orange
            )
            
            Divider().padding(.leading, 50)
            
            InfoRowView(
                icon: "dollarsign.circle",
                title: "Currency",
                value: user.defaultCurrency,
                color: .green
            )
            
            Divider().padding(.leading, 50)
            
            InfoRowView(
                icon: "network",
                title: "Preferred Network",
                value: user.preferredNetwork,
                color: .purple
            )
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingEditProfile = true
            } label: {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            Button {
                let shareText = "Add me on Zuno! @\(user.zunoTag)"
                let activityVC = UIActivityViewController(
                    activityItems: [shareText],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    
                    Text("Share Profile")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Info Row View

struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct UserProfileView_Previews: PreviewProvider {
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
        
        UserProfileView(
            user: user,
            walletCount: 3,
            totalBalance: "US$ 1,234.56",
            modelContext: container.mainContext
        )
    }
}
