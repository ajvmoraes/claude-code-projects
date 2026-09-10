import Foundation

/// On-disk shape of a backup file. Server metadata is plain JSON so it's easy to inspect
/// or hand-edit; a stored password (if any) is individually AES-GCM encrypted using a
/// passphrase chosen at export time. SSH key *files* are never copied — only the path
/// the server referenced, so the corresponding ~/.ssh key must already exist on the
/// destination Mac (or be copied there separately).
struct BackupDocument: Codable {
    struct Entry: Codable {
        var server: SSHServer
        var encryptedPassword: String?
    }

    var version: Int = 1
    var exportedAt: Date = Date()
    var kdfSaltBase64: String?
    var kdfIterations: Int?
    var entries: [Entry]
}

enum ExportImportService {
    struct ImportResult {
        var imported: [SSHServer]
        var passwordsRestored: Int
        var passwordsSkipped: Int
    }

    /// Builds a backup document. Pass a non-empty `passphrase` to also include encrypted
    /// passwords for servers whose auth method is `.password` and that have one saved.
    static func makeBackup(servers: [SSHServer], passphrase: String?) -> BackupDocument {
        let trimmedPassphrase = passphrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        let salt: Data? = (trimmedPassphrase?.isEmpty == false) ? CryptoService.randomSalt() : nil

        let entries: [BackupDocument.Entry] = servers.map { server in
            var encrypted: String?
            if let passphrase = trimmedPassphrase, !passphrase.isEmpty,
               let salt,
               server.authMethod == .password,
               let plainPassword = KeychainService.readPassword(for: server.id) {
                encrypted = CryptoService.encrypt(
                    plaintext: plainPassword,
                    passphrase: passphrase,
                    salt: salt,
                    iterations: CryptoService.pbkdf2Iterations
                )
            }
            return BackupDocument.Entry(server: server, encryptedPassword: encrypted)
        }

        return BackupDocument(
            exportedAt: Date(),
            kdfSaltBase64: salt?.base64EncodedString(),
            kdfIterations: salt != nil ? CryptoService.pbkdf2Iterations : nil,
            entries: entries
        )
    }

    static func encodeToFile(_ document: BackupDocument, url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    static func decodeFromFile(url: URL) throws -> BackupDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupDocument.self, from: data)
    }

    /// Restores servers from a backup document. If any entry carries an encrypted password,
    /// pass the export passphrase to decrypt and store it back into the Keychain; otherwise
    /// those entries are imported without a password (auth method stays `.password`, the
    /// user re-enters it on first connect).
    static func restore(document: BackupDocument, passphrase: String?) -> ImportResult {
        var imported: [SSHServer] = []
        var restored = 0
        var skipped = 0

        let salt = document.kdfSaltBase64.flatMap { Data(base64Encoded: $0) }
        let iterations = document.kdfIterations ?? CryptoService.pbkdf2Iterations

        for entry in document.entries {
            imported.append(entry.server)
            guard let encrypted = entry.encryptedPassword else { continue }
            guard let passphrase, !passphrase.isEmpty, let salt else {
                skipped += 1
                continue
            }
            if let plain = CryptoService.decrypt(base64: encrypted, passphrase: passphrase, salt: salt, iterations: iterations) {
                KeychainService.savePassword(plain, for: entry.server.id)
                restored += 1
            } else {
                skipped += 1
            }
        }

        return ImportResult(imported: imported, passwordsRestored: restored, passwordsSkipped: skipped)
    }
}
