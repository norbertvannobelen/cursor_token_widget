import Foundation
import os
import Security

private let keychainLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "keychain")

enum KeychainStore {
    private static let service = "org.tx.cursortokenwidget"
    /// Matches the team keychain group allowed by the Mac development profile.
    private static let accessGroup = "2CSRPDZQ8D.org.tx.cursortokenwidget"

    static func save(_ data: Data, account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            keychainLogger.error("save \(account, privacy: .public) status=\(status)")
        }
    }

    static func load(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                keychainLogger.error("load \(account, privacy: .public) status=\(status)")
            }
            return nil
        }
        return result as? Data
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
