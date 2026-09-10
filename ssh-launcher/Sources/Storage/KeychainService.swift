import Foundation
import Security

/// Thin wrapper around the platform Keychain for storing per-server secrets: SSH
/// passwords (used by both the Mac and mobile apps) and, on the mobile app, the text
/// of an imported private key (there is no `~/.ssh` path to reference inside the iOS
/// sandbox, so the key content itself has to live somewhere secure). Nothing here
/// ever touches disk outside the Keychain or gets written to servers.json.
enum KeychainService {
    private static let passwordService = "com.avs.sshlauncher.password"
    private static let privateKeyService = "com.avs.sshlauncher.privatekey"
    private static let keyPassphraseService = "com.avs.sshlauncher.keypassphrase"

    private static func account(for serverID: UUID) -> String {
        serverID.uuidString
    }

    private static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func savePassword(_ password: String, for serverID: UUID) {
        save(password, service: passwordService, account: account(for: serverID))
    }

    static func readPassword(for serverID: UUID) -> String? {
        read(service: passwordService, account: account(for: serverID))
    }

    static func deletePassword(for serverID: UUID) {
        delete(service: passwordService, account: account(for: serverID))
    }

    static func hasPassword(for serverID: UUID) -> Bool {
        readPassword(for: serverID) != nil
    }

    /// The mobile app stores the pasted/imported private key text itself here
    /// (macOS instead just keeps a filesystem path in `SSHServer.identityFilePath`).
    static func savePrivateKeyText(_ keyText: String, for serverID: UUID) {
        save(keyText, service: privateKeyService, account: account(for: serverID))
    }

    static func readPrivateKeyText(for serverID: UUID) -> String? {
        read(service: privateKeyService, account: account(for: serverID))
    }

    static func deletePrivateKeyText(for serverID: UUID) {
        delete(service: privateKeyService, account: account(for: serverID))
    }

    static func hasPrivateKeyText(for serverID: UUID) -> Bool {
        readPrivateKeyText(for: serverID) != nil
    }

    /// Passphrase that decrypts the private key itself (separate from the SSH login
    /// password). Only meaningful alongside a stored private key.
    static func saveKeyPassphrase(_ passphrase: String, for serverID: UUID) {
        save(passphrase, service: keyPassphraseService, account: account(for: serverID))
    }

    static func readKeyPassphrase(for serverID: UUID) -> String? {
        read(service: keyPassphraseService, account: account(for: serverID))
    }

    static func deleteKeyPassphrase(for serverID: UUID) {
        delete(service: keyPassphraseService, account: account(for: serverID))
    }
}
