import Foundation
import Security

/// Thin wrapper around the macOS Keychain for storing per-server SSH passwords.
/// Passwords never touch disk outside the Keychain and are never written to servers.json.
enum KeychainService {
    private static let service = "com.avs.sshlauncher.password"

    private static func account(for serverID: UUID) -> String {
        serverID.uuidString
    }

    static func savePassword(_ password: String, for serverID: UUID) {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serverID)
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func readPassword(for serverID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serverID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for serverID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serverID)
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasPassword(for serverID: UUID) -> Bool {
        readPassword(for: serverID) != nil
    }
}
