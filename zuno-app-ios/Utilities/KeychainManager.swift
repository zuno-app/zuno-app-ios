import Foundation
import Security

/// Secure keychain storage manager
final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    /// Save data to keychain
    func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }

    /// Save string to keychain
    func save(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, forKey: key)
    }

    /// Retrieve data from keychain
    func retrieve(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }

        return data
    }

    /// Retrieve string from keychain
    func retrieveString(forKey key: String) throws -> String {
        let data = try retrieve(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    /// Delete item from keychain
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }

    /// Delete all items
    func deleteAll() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }

    /// Check if item exists
    func exists(forKey key: String) -> Bool {
        do {
            _ = try retrieve(forKey: key)
            return true
        } catch {
            return false
        }
    }
}

enum KeychainError: LocalizedError {
    case unableToSave
    case unableToDelete
    case notFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unableToSave: return "Unable to save to keychain"
        case .unableToDelete: return "Unable to delete from keychain"
        case .notFound: return "Item not found in keychain"
        case .invalidData: return "Invalid data format"
        }
    }
}
