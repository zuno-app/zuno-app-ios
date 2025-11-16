import SwiftUI

/// Welcome screen - first screen users see
struct WelcomeView: View {
    @State private var showingRegister = false
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // App logo and title
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)

                        Text("Zuno Wallet")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Your gateway to Web3")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    // Features list
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(
                            icon: "faceid",
                            title: "Secure with Face ID",
                            description: "Biometric authentication keeps your wallet safe"
                        )

                        FeatureRow(
                            icon: "arrow.left.arrow.right",
                            title: "Send & Receive",
                            description: "Easy payments with @zuno tags"
                        )

                        FeatureRow(
                            icon: "network",
                            title: "Multi-Chain Support",
                            description: "Arc, Polygon, Arbitrum, and more"
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            showingRegister = true
                        }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(16)
                        }

                        Button(action: {
                            showingLogin = true
                        }) {
                            Text("I already have an account")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationDestination(isPresented: $showingRegister) {
                ZunoTagInputView(isRegistration: true)
            }
            .navigationDestination(isPresented: $showingLogin) {
                ZunoTagInputView(isRegistration: false)
            }
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
