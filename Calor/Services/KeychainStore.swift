//
//  KeychainStore.swift
//  Calor
//

import Foundation
import Security

/// The Claude API key, kept in the iOS Keychain (encrypted, never in backups or the code).
/// "This device only": it stays on this iPhone and isn't copied to a new one.
enum KeychainStore {
    private static let service = "com.sufimazlan.Calor"
    private static let account = "claude-api-key"

    struct KeychainError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "The key couldn't be saved in the Keychain (error \(status))." }
    }

    static var apiKey: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    static func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    static func deleteAPIKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    /// "sk-ant-…a1b2", to show which key is saved without showing the key.
    static func masked(_ key: String) -> String {
        guard key.count > 12 else { return "••••" }
        return "\(key.prefix(7))…\(key.suffix(4))"
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum FoodAnalyzers {
    /// Claude when an API key is saved, otherwise demo results.
    static var current: any FoodAnalyzer {
        guard let key = KeychainStore.apiKey else { return DemoFoodAnalyzer() }
        return ClaudeFoodAnalyzer(apiKey: key, model: .current)
    }
}
