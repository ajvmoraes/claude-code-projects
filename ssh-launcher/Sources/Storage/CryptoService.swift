import Foundation
import CryptoKit
import CommonCrypto

/// PBKDF2 + AES-GCM helpers used only to protect passwords inside export/import backup files.
/// SSH private keys themselves are never exported — only server metadata and, optionally,
/// passwords that would otherwise live in the Keychain.
enum CryptoService {
    static let pbkdf2Iterations: Int = 200_000
    static let saltLength = 16

    static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let passphraseBytes = Array(passphrase.utf8)
        let saltBytes = Array(salt)

        _ = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passphraseBytes, passphraseBytes.count,
            saltBytes, saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(iterations),
            &derived, derived.count
        )
        return SymmetricKey(data: derived)
    }

    /// Encrypts `plaintext` with a key derived from `passphrase` and `salt`.
    /// Returns base64-encoded (nonce || ciphertext || tag).
    static func encrypt(plaintext: String, passphrase: String, salt: Data, iterations: Int) -> String? {
        let key = deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        guard let sealed = try? AES.GCM.seal(Data(plaintext.utf8), using: key) else { return nil }
        guard let combined = sealed.combined else { return nil }
        return combined.base64EncodedString()
    }

    static func decrypt(base64: String, passphrase: String, salt: Data, iterations: Int) -> String? {
        guard let combined = Data(base64Encoded: base64) else { return nil }
        let key = deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        guard let box = try? AES.GCM.SealedBox(combined: combined) else { return nil }
        guard let data = try? AES.GCM.open(box, using: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
