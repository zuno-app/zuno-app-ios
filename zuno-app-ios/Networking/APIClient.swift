import Foundation

/// Network API client for backend communication
final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        guard let url = URL(string: Config.apiBaseURL) else {
            fatalError("Invalid API base URL")
        }
        self.baseURL = url

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Request Methods

    /// Perform GET request
    func get<T: Decodable>(
        _ endpoint: String,
        authenticated: Bool = false
    ) async throws -> T {
        try await request(endpoint, method: "GET", authenticated: authenticated)
    }

    /// Perform POST request
    func post<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        authenticated: Bool = false
    ) async throws -> T {
        try await request(endpoint, method: "POST", body: body, authenticated: authenticated)
    }

    /// Perform PUT request
    func put<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        authenticated: Bool = false
    ) async throws -> T {
        try await request(endpoint, method: "PUT", body: body, authenticated: authenticated)
    }

    /// Perform DELETE request
    func delete<T: Decodable>(
        _ endpoint: String,
        authenticated: Bool = false
    ) async throws -> T {
        try await request(endpoint, method: "DELETE", authenticated: authenticated)
    }

    // MARK: - Generic Request

    private func request<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        method: String,
        body: Body? = nil as String?,
        authenticated: Bool = false
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication token
        if authenticated {
            let token = try KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.accessToken)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw NetworkError.apiError(apiError)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Authentication APIs

    func register(zunoTag: String, displayName: String?) async throws -> RegisterResponse {
        let request = RegisterRequest(zunoTag: zunoTag, email: nil, displayName: displayName)
        return try await post(Config.Endpoints.register, body: request)
    }

    // MARK: - User APIs

    func getCurrentUser() async throws -> UserResponse {
        try await get(Config.Endpoints.userProfile, authenticated: true)
    }

    func updateUser(email: String?, displayName: String?, defaultCurrency: String?, preferredNetwork: String?) async throws -> UserResponse {
        let request = UpdateUserRequest(
            email: email,
            displayName: displayName,
            defaultCurrency: defaultCurrency,
            preferredNetwork: preferredNetwork
        )
        return try await put(Config.Endpoints.userProfile, body: request, authenticated: true)
    }

    // MARK: - Wallet APIs

    func createWallet(blockchain: String) async throws -> WalletResponse {
        let request = CreateWalletRequest(blockchain: blockchain, accountType: "SCA", name: nil)
        return try await post(Config.Endpoints.wallets, body: request, authenticated: true)
    }

    func listWallets() async throws -> [WalletResponse] {
        try await get(Config.Endpoints.wallets, authenticated: true)
    }

    // MARK: - Transaction APIs

    func sendTransaction(toAddress: String?, toZunoTag: String?, amount: String, tokenSymbol: String, blockchain: String) async throws -> TransactionResponse {
        let request = SendTransactionRequest(
            toAddress: toAddress,
            toZunoTag: toZunoTag,
            amount: amount,
            tokenSymbol: tokenSymbol,
            blockchain: blockchain,
            description: nil
        )
        return try await post(Config.Endpoints.sendTransaction, body: request, authenticated: true)
    }

    func getTransactions() async throws -> [TransactionResponse] {
        try await get(Config.Endpoints.transactions, authenticated: true)
    }

    // MARK: - Zuno Tag APIs

    func lookupZunoTag(_ tag: String) async throws -> ZunoTagLookupResponse {
        try await get(Config.Endpoints.zunoTagLookup(tag), authenticated: true)
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(APIError)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let error):
            return error.message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
