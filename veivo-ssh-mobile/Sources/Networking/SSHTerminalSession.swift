import Foundation
import Citadel
import NIO
import NIOSSH
import Crypto

enum SSHSessionError: LocalizedError {
    case missingCredential(String)
    case unsupportedKeyFormat

    var errorDescription: String? {
        switch self {
        case .missingCredential(let message):
            return message
        case .unsupportedKeyFormat:
            return "Não foi possível ler essa chave. Só chaves Ed25519 e RSA no formato OpenSSH são suportadas (verifique também a senha da chave, se houver)."
        }
    }
}

/// Bridges a real SSH connection (via Citadel/swift-nio-ssh) to SwiftTerm's terminal
/// view: unlike the Mac app, iOS can't spawn `/usr/bin/ssh` as a child process (the
/// sandbox forbids exec of arbitrary binaries), so the SSH protocol itself runs
/// in-process here.
@MainActor
final class SSHTerminalSession: ObservableObject {
    enum State: Equatable {
        case connecting
        case connected
        case failed(String)
        case closed
    }

    @Published private(set) var state: State = .connecting

    /// Raw bytes received from the remote pty, ready to feed into SwiftTerm.
    var onOutput: ((ArraySlice<UInt8>) -> Void)?

    private let server: SSHServer
    private var client: SSHClient?
    private var stdinWriter: TTYStdinWriter?

    init(server: SSHServer) {
        self.server = server
    }

    func start(cols: Int, rows: Int) {
        Task { await connect(cols: cols, rows: rows) }
    }

    func send(_ data: ArraySlice<UInt8>) {
        guard let stdinWriter else { return }
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        Task { try? await stdinWriter.write(buffer) }
    }

    func resize(cols: Int, rows: Int) {
        guard let stdinWriter else { return }
        Task { try? await stdinWriter.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0) }
    }

    func close() {
        let client = client
        Task { try? await client?.close() }
        _ = client
    }

    private func connect(cols: Int, rows: Int) async {
        do {
            let authMethod = try buildAuthMethod()
            let client = try await SSHClient.connect(
                host: server.host,
                port: server.port,
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            self.client = client
            state = .connected

            let request = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: cols,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: SSHTerminalModes([:])
            )

            try await client.withPTY(request) { [weak self] inbound, outbound in
                guard let self else { return }
                self.stdinWriter = outbound
                for try await chunk in inbound {
                    let buffer: ByteBuffer
                    switch chunk {
                    case .stdout(let b), .stderr(let b):
                        buffer = b
                    }
                    let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) ?? []
                    self.onOutput?(bytes[...])
                }
            }
            if case .connected = state {
                state = .closed
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func buildAuthMethod() throws -> SSHAuthenticationMethod {
        switch server.authMethod {
        case .password:
            guard let password = KeychainService.readPassword(for: server.id), !password.isEmpty else {
                throw SSHSessionError.missingCredential("Nenhuma senha salva para este servidor. Edite o servidor e informe a senha.")
            }
            return .passwordBased(username: server.username, password: password)

        case .key:
            guard let keyText = KeychainService.readPrivateKeyText(for: server.id), !keyText.isEmpty else {
                throw SSHSessionError.missingCredential("Nenhuma chave privada importada para este servidor. Edite o servidor e importe/cole a chave.")
            }
            let passphrase = KeychainService.readKeyPassphrase(for: server.id)
            let decryptionKey = passphrase.map { Data($0.utf8) }

            if let key = try? Curve25519.Signing.PrivateKey(sshEd25519: keyText, decryptionKey: decryptionKey) {
                return .ed25519(username: server.username, privateKey: key)
            }
            if let key = try? Insecure.RSA.PrivateKey(sshRsa: keyText, decryptionKey: decryptionKey) {
                return .rsa(username: server.username, privateKey: key)
            }
            throw SSHSessionError.unsupportedKeyFormat

        case .agentOrDefault:
            throw SSHSessionError.missingCredential("Escolha \"Chave SSH\" ou \"Senha\" como autenticação — não existe agente do sistema no iOS.")
        }
    }
}
