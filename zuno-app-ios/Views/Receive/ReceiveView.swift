import SwiftUI
import CoreImage.CIFilterBuiltins

/// Receive screen with QR code and address
struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss

    let wallet: LocalWallet?

    @State private var selectedTab: ReceiveTab = .address
    @State private var showingShareSheet = false
    @State private var showCopiedToast = false

    enum ReceiveTab: String, CaseIterable {
        case address = "Address"
        case qrCode = "QR Code"

        var icon: String {
            switch self {
            case .address: return "doc.text"
            case .qrCode: return "qrcode"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let wallet = wallet {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Tab Selector
                            tabSelector

                            // Content based on selected tab
                            if selectedTab == .qrCode {
                                qrCodeView(wallet: wallet)
                            } else {
                                addressView(wallet: wallet)
                            }

                            // Network Info
                            networkInfo(wallet: wallet)

                            // Action Buttons
                            actionButtons(wallet: wallet)

                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                } else {
                    noWalletView
                }

                // Copied Toast
                if showCopiedToast {
                    copiedToast
                }
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let wallet = wallet {
                    ShareSheet(items: [generateShareText(wallet: wallet)])
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(ReceiveTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - QR Code View

    private func qrCodeView(wallet: LocalWallet) -> some View {
        VStack(spacing: 24) {
            // QR Code
            VStack(spacing: 16) {
                if let qrImage = generateQRCode(from: wallet.walletAddress) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                } else {
                    placeholderQRCode
                }

                Text("Scan to receive")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Address below QR
            Text(wallet.walletAddress)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Address View

    private func addressView(wallet: LocalWallet) -> some View {
        VStack(spacing: 16) {
            // Wallet icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }

            Text("Your Wallet Address")
                .font(.headline)

            // Address card
            VStack(spacing: 12) {
                Text(wallet.walletAddress)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                Button {
                    copyAddress(wallet.walletAddress)
                } label: {
                    Label("Copy Address", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Network Info

    private func networkInfo(wallet: LocalWallet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.headline)

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

            Text("Only send \(wallet.blockchainDisplayName) assets to this address")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(wallet: LocalWallet) -> some View {
        VStack(spacing: 12) {
            Button {
                copyAddress(wallet.walletAddress)
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(16)
            }

            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - No Wallet View

    private var noWalletView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Wallet Selected")
                .font(.title3.bold())

            Text("Please select a wallet to receive funds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Placeholder QR Code

    private var placeholderQRCode: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 250, height: 250)

            Image(systemName: "qrcode")
                .font(.system(size: 100))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Address copied to clipboard")
                    .font(.subheadline)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: showCopiedToast)
    }

    // MARK: - Helper Methods

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func copyAddress(_ address: String) {
        UIPasteboard.general.string = address
        showCopiedToast = true

        // Hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func generateShareText(wallet: LocalWallet) -> String {
        return """
        Send me crypto on \(wallet.blockchainDisplayName)

        My address:
        \(wallet.walletAddress)

        Sent via Zuno Wallet
        """
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let wallet = LocalWallet(
        id: "1",
        walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1",
        blockchain: "ARC-TESTNET",
        accountType: "SCA",
        isPrimary: true
    )

    return ReceiveView(wallet: wallet)
}

#Preview("No Wallet") {
    ReceiveView(wallet: nil)
}
