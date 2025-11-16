import SwiftUI
import CoreNFC
import Combine

/// Tap to Pay screen with NFC functionality
struct TapToPayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nfcManager = NFCManager()

    @State private var paymentAmount: String = ""
    @State private var paymentDescription: String = ""
    @State private var isReadyToPay = false
    @State private var showingPaymentRequest = false
    @FocusState private var focusedField: Field?

    enum Field {
        case amount, description
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isReadyToPay {
                    nfcScanView
                } else {
                    setupView
                }
            }
            .navigationTitle("Tap to Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("NFC Not Available", isPresented: $nfcManager.showError) {
                Button("OK") {
                    nfcManager.clearError()
                }
            } message: {
                if let error = nfcManager.errorMessage {
                    Text(error)
                }
            }
            .alert("Payment Received!", isPresented: $nfcManager.showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Successfully received \(paymentAmount) USDC")
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "wave.3.right")
                            .font(.system(size: 50))
                            .foregroundStyle(.purple)
                    }

                    Text("Tap to Receive Payment")
                        .font(.title2.bold())

                    Text("Set your payment amount and hold your phone near another device to receive")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)

                // Amount Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Amount")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack {
                        TextField("0.00", text: $paymentAmount)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("USDC")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Description Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .padding(.horizontal)

                    TextField("What's this for?", text: $paymentDescription)
                        .focused($focusedField, equals: .description)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Spacer()

                // Ready Button
                Button {
                    prepareForPayment()
                } label: {
                    Text("Ready to Receive")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isValidAmount ? Color.purple : Color.gray)
                        .cornerRadius(16)
                }
                .disabled(!isValidAmount)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - NFC Scan View

    private var nfcScanView: some View {
        VStack(spacing: 40) {
            Spacer()

            // NFC Animation
            VStack(spacing: 20) {
                ZStack {
                    // Pulsing circles
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                            .frame(width: 150 + CGFloat(index * 50),
                                   height: 150 + CGFloat(index * 50))
                            .scaleEffect(nfcManager.isScanning ? 1.2 : 1.0)
                            .opacity(nfcManager.isScanning ? 0.0 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.3),
                                value: nfcManager.isScanning
                            )
                    }

                    // Center icon
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 150, height: 150)

                        Image(systemName: "wave.3.right")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple)
                    }
                }

                Text("Hold Near Device")
                    .font(.title.bold())

                Text("Waiting for payment device...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Payment Details
            VStack(spacing: 16) {
                HStack {
                    Text("Amount:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(paymentAmount) USDC")
                        .font(.headline)
                }

                if !paymentDescription.isEmpty {
                    HStack {
                        Text("Description:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(paymentDescription)
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Cancel Button
            Button {
                cancelPayment()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .onAppear {
            nfcManager.startNFCSession(amount: paymentAmount, description: paymentDescription)
        }
    }

    // MARK: - Helper Methods

    private var isValidAmount: Bool {
        guard let amount = Double(paymentAmount), amount > 0 else {
            return false
        }
        return true
    }

    private func prepareForPayment() {
        focusedField = nil
        isReadyToPay = true
    }

    private func cancelPayment() {
        nfcManager.cancelNFCSession()
        isReadyToPay = false
    }
}

// MARK: - NFC Manager

@MainActor
class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?

    private var nfcSession: NFCNDEFReaderSession?
    private var paymentAmount: String = ""
    private var paymentDescription: String = ""

    func startNFCSession(amount: String, description: String) {
        self.paymentAmount = amount
        self.paymentDescription = description

        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            showError = true
            return
        }

        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near the payment device"
        nfcSession?.begin()
        isScanning = true
    }

    func cancelNFCSession() {
        nfcSession?.invalidate()
        isScanning = false
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - NFC Delegate

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User canceled, no error
                    break
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Successfully read, show success
                    self.showSuccess = true
                default:
                    self.errorMessage = "NFC error: \(nfcError.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            // Process NDEF messages
            for message in messages {
                for record in message.records {
                    // Parse payment data from NFC tag
                    if let payload = String(data: record.payload, encoding: .utf8) {
                        print("Received payment data: \(payload)")
                        // TODO: Process payment and send to backend
                    }
                }
            }

            session.alertMessage = "Payment received!"
            session.invalidate()
            self.showSuccess = true
            self.isScanning = false
        }
    }
}

// MARK: - Preview

#Preview {
    TapToPayView()
}
