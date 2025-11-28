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
        // Use custom date decoder to handle ISO8601 with fractional seconds
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

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
    
    /// Perform POST request with dictionary body
    func post<T: Decodable>(
        _ endpoint: String,
        body: [String: Any],
        authenticated: Bool = false
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🌐 [APIClient] POST \(url)")

        // Add authentication token
        if authenticated {
            let token = try KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.accessToken)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("   🔐 Using authentication token")
        }

        // Add body
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIClient] Invalid response type")
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [APIClient] HTTP error: \(httpResponse.statusCode)")
                // Try to decode error
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    print("❌ [APIClient] API error: \(apiError.message)")
                    throw NetworkError.apiError(apiError)
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }

            print("✓ [APIClient] Success: \(httpResponse.statusCode)")
            return try decoder.decode(T.self, from: data)
            
        } catch let error as NetworkError {
            // Already a NetworkError, just rethrow
            throw error
            
        } catch let urlError as URLError {
            // Convert URLError to NetworkError
            print("❌ [APIClient] URLError: \(urlError.localizedDescription)")
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.invalidResponse
            }
            
        } catch {
            // Decoding error or other error
            print("❌ [APIClient] Unexpected error: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        }
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

        print("🌐 [APIClient] \(method) \(url)")

        // Add authentication token
        if authenticated {
            let token = try KeychainManager.shared.retrieveString(forKey: Config.KeychainKeys.accessToken)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("   🔐 Using authentication token")
        }

        // Add body
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIClient] Invalid response type")
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [APIClient] HTTP error: \(httpResponse.statusCode)")
                // Try to decode error
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    print("❌ [APIClient] API error: \(apiError.message)")
                    throw NetworkError.apiError(apiError)
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }

            print("✓ [APIClient] Success: \(httpResponse.statusCode)")
            return try decoder.decode(T.self, from: data)
            
        } catch let error as NetworkError {
            // Already a NetworkError, just rethrow
            throw error
            
        } catch let urlError as URLError {
            // Convert URLError to NetworkError
            print("❌ [APIClient] URLError: \(urlError.localizedDescription)")
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.invalidResponse
            }
            
        } catch {
            // Decoding error or other error
            print("❌ [APIClient] Unexpected error: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Authentication APIs

    func register(zunoTag: String, displayName: String?, email: String? = nil) async throws -> RegisterResponse {
        let request = RegisterRequest(zunoTag: zunoTag, email: email, displayName: displayName)
        return try await post(Config.Endpoints.register, body: request)
    }

    // MARK: - User APIs

    func getCurrentUser() async throws -> UserResponse {
        try await get(Config.Endpoints.userProfile, authenticated: true)
    }

    func updateUser(email: String?, displayName: String?, defaultCurrency: String?, preferredNetwork: String?, preferredStablecoin: String? = nil) async throws -> UserResponse {
        let request = UpdateUserRequest(
            email: email,
            displayName: displayName,
            defaultCurrency: defaultCurrency,
            preferredNetwork: preferredNetwork,
            preferredStablecoin: preferredStablecoin
        )
        return try await put(Config.Endpoints.userProfile, body: request, authenticated: true)
    }

    // MARK: - Wallet APIs

    func createWallet(blockchain: String) async throws -> WalletResponse {
        print("🌐 [APIClient] Creating wallet on blockchain: \(blockchain)")
        let request = CreateWalletRequest(blockchain: blockchain, accountType: "SCA", name: nil)
        do {
            let wallet: WalletResponse = try await post(Config.Endpoints.wallets, body: request, authenticated: true)
            print("✓ [APIClient] Successfully created wallet: \(wallet.walletAddress)")
            return wallet
        } catch {
            print("❌ [APIClient] Failed to create wallet: \(error)")
            throw error
        }
    }

    func listWallets() async throws -> [WalletResponse] {
        print("🌐 [APIClient] Fetching wallets from: \(Config.Endpoints.wallets)")
        do {
            let wallets: [WalletResponse] = try await get(Config.Endpoints.wallets, authenticated: true)
            print("✓ [APIClient] Successfully fetched \(wallets.count) wallets")
            return wallets
        } catch {
            print("❌ [APIClient] Failed to fetch wallets: \(error)")
            throw error
        }
    }

    // MARK: - Transaction APIs

    func sendTransaction(toAddress: String?, toZunoTag: String?, amount: String, tokenSymbol: String, blockchain: String, description: String? = nil, category: String? = nil) async throws -> TransactionResponse {
        let request = SendTransactionRequest(
            toAddress: toAddress,
            toZunoTag: toZunoTag,
            amount: amount,
            tokenSymbol: tokenSymbol,
            blockchain: blockchain,
            description: description,
            category: category
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
    
    /// Check if a zuno tag is available (for registration)
    func checkZunoTagAvailability(_ tag: String) async throws -> Bool {
        do {
            let _: ZunoTagAvailabilityResponse = try await get("auth/check-tag/\(tag)", authenticated: false)
            return true // Tag is available
        } catch NetworkError.httpError(409) {
            return false // Tag is taken (conflict)
        } catch NetworkError.httpError(404) {
            return true // Tag not found = available
        }
    }
    
    /// Check if an email is available (for registration/update)
    func checkEmailAvailability(_ email: String) async throws -> Bool {
        do {
            let _: EmailAvailabilityResponse = try await get("auth/check-email/\(email)", authenticated: false)
            return true // Email is available
        } catch NetworkError.httpError(409) {
            return false // Email is taken (conflict)
        } catch NetworkError.httpError(404) {
            return true // Email not found = available
        }
    }
    
    // MARK: - Balance Aggregation APIs
    
    /// Get aggregated balance across all wallets with real-time fiat valuations
    func getAggregatedBalance() async throws -> AggregatedBalanceResponse {
        print("📊 [APIClient] Fetching aggregated balance")
        return try await get("balances/aggregated", authenticated: true)
    }
    
    /// Convert price between currencies in real-time
    func convertPrice(amount: Double, from: String, to: String) async throws -> PriceConversionResponse {
        print("💱 [APIClient] Converting \(amount) \(from) to \(to)")
        let request = PriceConversionRequest(amount: amount, fromCurrency: from, toCurrency: to)
        return try await post("prices/convert", body: request, authenticated: true)
    }
    
    /// Get current exchange rates
    func getExchangeRates() async throws -> ExchangeRatesResponse {
        print("📈 [APIClient] Fetching exchange rates")
        return try await get("prices/rates", authenticated: true)
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(APIError)
    case decodingError(Error)
    case noConnection
    case timeout

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
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        }
    }
}
