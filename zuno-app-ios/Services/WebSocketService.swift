//
//  WebSocketService.swift
//  zuno-app-ios
//
//  Real-time WebSocket connection for instant transaction updates
//

import Foundation
import Combine

/// WebSocket service for real-time communication with backend
class WebSocketService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var authToken: String?
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    
    // Event publishers
    private let transactionEventSubject = PassthroughSubject<TransactionEvent, Never>()
    private let balanceEventSubject = PassthroughSubject<BalanceEvent, Never>()
    private let errorEventSubject = PassthroughSubject<String, Never>()
    
    // MARK: - Public Publishers
    
    var transactionEvents: AnyPublisher<TransactionEvent, Never> {
        transactionEventSubject.eraseToAnyPublisher()
    }
    
    var balanceEvents: AnyPublisher<BalanceEvent, Never> {
        balanceEventSubject.eraseToAnyPublisher()
    }
    
    var errorEvents: AnyPublisher<String, Never> {
        errorEventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Connection Status
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed
    }

    // MARK: - Initialization
    
    init() {
        self.urlSession = URLSession(configuration: .default)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    /// Connect to WebSocket with authentication
    func connect(authToken: String) {
        guard !isConnected else { return }
        
        self.authToken = authToken
        connectionStatus = .connecting
        
        // Convert HTTP URL to WebSocket URL
        let baseURL = Config.apiBaseURL
        let wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
                          .replacingOccurrences(of: "https://", with: "wss://")
        
        guard let url = URL(string: "\(wsURL)/ws") else {
            print("❌ [WebSocket] Invalid WebSocket URL")
            connectionStatus = .failed
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        listenForMessages()
        
        // Start heartbeat
        startHeartbeat()
        
        print("🔌 [WebSocket] Connecting to \(url)")
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        stopHeartbeat()
        stopReconnectTimer()
        
        isConnected = false
        connectionStatus = .disconnected
        reconnectAttempts = 0
        
        print("🔌 [WebSocket] Disconnected")
    }
    
    // MARK: - Message Handling
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.listenForMessages()
                
            case .failure(let error):
                print("❌ [WebSocket] Receive error: \(error)")
                self?.handleConnectionError()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleTextMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func handleTextMessage(_ text: String) {
        print("📨 [WebSocket] Received: \(text)")
        
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let event = try JSONDecoder().decode(WebSocketEvent.self, from: data)
            
            DispatchQueue.main.async {
                self.handleWebSocketEvent(event)
            }
        } catch {
            print("❌ [WebSocket] Failed to decode message: \(error)")
        }
    }
    
    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event.type {
        case "connected":
            isConnected = true
            connectionStatus = .connected
            reconnectAttempts = 0
            print("✅ [WebSocket] Connected successfully")
            
        case "transaction_received", "transaction_updated":
            if let txEvent = event.transactionEvent {
                print("💰 [WebSocket] Transaction: \(txEvent.transactionType) \(txEvent.amount) \(txEvent.tokenSymbol)")
                transactionEventSubject.send(txEvent)
            }
            
        case "balance_updated":
            if let balEvent = event.balanceEvent {
                print("💰 [WebSocket] Balance updated for wallet \(balEvent.walletId)")
                balanceEventSubject.send(balEvent)
            }
            
        case "pong":
            print("🏓 [WebSocket] Pong received")
            
        case "error":
            if let message = event.errorMessage {
                print("❌ [WebSocket] Server error: \(message)")
                errorEventSubject.send(message)
            }
            
        default:
            print("⚠️ [WebSocket] Unknown event type: \(event.type)")
        }
    }
    
    // MARK: - Sending Messages
    
    /// Subscribe to wallet updates
    func subscribeToWallets(_ walletIds: [String]) {
        let message = WebSocketOutMessage(type: "subscribe", walletIds: walletIds)
        sendMessage(message)
    }
    
    /// Request immediate refresh
    func requestRefresh(walletId: String? = nil) {
        let message = WebSocketOutMessage(type: "refresh", walletId: walletId)
        sendMessage(message)
    }
    
    private func sendMessage(_ message: WebSocketOutMessage) {
        guard isConnected else {
            print("⚠️ [WebSocket] Cannot send message - not connected")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let text = String(data: data, encoding: .utf8) ?? ""
            
            webSocketTask?.send(.string(text)) { error in
                if let error = error {
                    print("❌ [WebSocket] Send error: \(error)")
                }
            }
        } catch {
            print("❌ [WebSocket] Failed to encode message: \(error)")
        }
    }

    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        let message = WebSocketOutMessage(type: "ping", timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        sendMessage(message)
    }
    
    // MARK: - Reconnection
    
    private func handleConnectionError() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .failed
            
            if self.reconnectAttempts < self.maxReconnectAttempts {
                self.scheduleReconnect()
            } else {
                print("❌ [WebSocket] Max reconnect attempts reached")
            }
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }
        
        reconnectAttempts += 1
        connectionStatus = .reconnecting
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        
        print("🔄 [WebSocket] Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let token = self.authToken else { return }
            self.connect(authToken: token)
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - WebSocket Message Models

struct WebSocketOutMessage: Codable {
    let type: String
    var walletIds: [String]?
    var walletId: String?
    var timestamp: Int64?
    
    enum CodingKeys: String, CodingKey {
        case type
        case walletIds = "wallet_ids"
        case walletId = "wallet_id"
        case timestamp
    }
}

struct WebSocketEvent: Codable {
    let type: String
    var transactionEvent: TransactionEvent?
    var balanceEvent: BalanceEvent?
    var errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        // Try to decode data based on event type
        if type == "transaction_received" || type == "transaction_updated" {
            transactionEvent = try? container.decode(TransactionEvent.self, forKey: .data)
        } else if type == "balance_updated" {
            balanceEvent = try? container.decode(BalanceEvent.self, forKey: .data)
        } else if type == "error" {
            if let errorData = try? container.decode([String: String].self, forKey: .data) {
                errorMessage = errorData["message"]
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
    }
}

struct TransactionEvent: Codable {
    let transactionId: String
    let walletId: String
    let transactionType: String
    let status: String
    let amount: String
    let tokenSymbol: String
    let fromAddress: String?
    let toAddress: String?
    let blockchainTxHash: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case walletId = "wallet_id"
        case transactionType = "transaction_type"
        case status
        case amount
        case tokenSymbol = "token_symbol"
        case fromAddress = "from_address"
        case toAddress = "to_address"
        case blockchainTxHash = "blockchain_tx_hash"
        case createdAt = "created_at"
    }
}

struct BalanceEvent: Codable {
    let walletId: String
    let walletAddress: String
    let balances: [WsTokenBalance]
    let totalUsd: Double
    
    enum CodingKeys: String, CodingKey {
        case walletId = "wallet_id"
        case walletAddress = "wallet_address"
        case balances
        case totalUsd = "total_usd"
    }
}

struct WsTokenBalance: Codable {
    let token: String
    let amount: String
    let valueUsd: Double
    
    enum CodingKeys: String, CodingKey {
        case token
        case amount
        case valueUsd = "value_usd"
    }
}

// Notification for transaction events
extension Notification.Name {
    static let transactionReceived = Notification.Name("transactionReceived")
}
