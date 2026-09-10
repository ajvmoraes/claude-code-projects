import SwiftUI
import AppKit

/// Add/edit sheet for a single server entry.
struct ServerFormView: View {
    enum Mode {
        case add
        case edit(SSHServer)
    }

    let mode: Mode
    var onSave: (SSHServer, String?) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var authMethod: SSHAuthMethod
    @State private var identityFilePath: String
    @State private var proxyJump: String
    @State private var extraArgs: String
    @State private var group: String
    @State private var notes: String
    @State private var password: String = ""
    @State private var hasExistingPassword: Bool

    private var serverID: UUID

    init(mode: Mode, onSave: @escaping (SSHServer, String?) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel

        let existing: SSHServer
        switch mode {
        case .add:
            existing = SSHServer()
        case .edit(let server):
            existing = server
        }
        serverID = existing.id
        _name = State(initialValue: existing.name)
        _host = State(initialValue: existing.host)
        _port = State(initialValue: String(existing.port))
        _username = State(initialValue: existing.username)
        _authMethod = State(initialValue: existing.authMethod)
        _identityFilePath = State(initialValue: existing.identityFilePath)
        _proxyJump = State(initialValue: existing.proxyJump)
        _extraArgs = State(initialValue: existing.extraArgs)
        _group = State(initialValue: existing.group)
        _notes = State(initialValue: existing.notes)
        _hasExistingPassword = State(initialValue: KeychainService.hasPassword(for: existing.id))
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Editar servidor" : "Novo servidor")
                .font(.headline)
                .padding()

            Form {
                Section("Identificação") {
                    TextField("Nome (ex: Servidor Produção)", text: $name)
                    TextField("Grupo (opcional, ex: Clientes/AVS)", text: $group)
                }

                Section("Conexão") {
                    TextField("Host / IP", text: $host)
                    TextField("Porta", text: $port)
                    TextField("Usuário", text: $username)
                }

                Section("Autenticação") {
                    Picker("Método", selection: $authMethod) {
                        ForEach(SSHAuthMethod.allCases) { method in
                            Text(method.label).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    if authMethod == .key {
                        HStack {
                            TextField("Caminho da chave (ex: ~/.ssh/id_ed25519)", text: $identityFilePath)
                            Button("Escolher…") { pickIdentityFile() }
                        }
                    }

                    if authMethod == .password {
                        SecureField(hasExistingPassword ? "Nova senha (deixe em branco para manter)" : "Senha", text: $password)
                        if hasExistingPassword {
                            Text("Uma senha já está salva no Keychain para este servidor.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("A senha fica guardada apenas no Keychain do macOS, nunca em texto puro.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Avançado (opcional)") {
                    TextField("Proxy Jump (-J usuario@bastion)", text: $proxyJump)
                    TextField("Argumentos extra do ssh", text: $extraArgs)
                    TextField("Notas", text: $notes)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(isEditing ? "Salvar" : "Adicionar") { save() }
                    .keyboardShortcut(.return)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 480, height: 560)
    }

    private func pickIdentityFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        panel.message = "Selecione o arquivo de chave privada"
        if panel.runModal() == .OK, let url = panel.url {
            identityFilePath = url.path
        }
    }

    private func save() {
        var server = SSHServer(
            id: serverID,
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespaces),
            authMethod: authMethod,
            identityFilePath: identityFilePath.trimmingCharacters(in: .whitespaces),
            proxyJump: proxyJump.trimmingCharacters(in: .whitespaces),
            extraArgs: extraArgs.trimmingCharacters(in: .whitespaces),
            group: group.trimmingCharacters(in: .whitespaces),
            notes: notes
        )
        if case .edit(let original) = mode {
            server.isFavorite = original.isFavorite
        }
        let newPassword = password.isEmpty ? nil : password
        onSave(server, newPassword)
    }
}
