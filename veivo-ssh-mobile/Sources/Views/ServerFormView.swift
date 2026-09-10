import SwiftUI
import UniformTypeIdentifiers

/// Add/edit sheet for a single server. Unlike the Mac app (which references a key file
/// by path), iOS has no stable `~/.ssh` path to point to, so the key's own text is
/// imported or pasted here and kept in the Keychain.
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
    @State private var group: String
    @State private var notes: String
    @State private var password: String = ""
    @State private var privateKeyText: String = ""
    @State private var keyPassphrase: String = ""
    @State private var hasExistingPassword: Bool
    @State private var hasExistingKey: Bool
    @State private var showingFileImporter = false
    @State private var importError: String?

    private var serverID: UUID

    init(mode: Mode, onSave: @escaping (SSHServer, String?) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel

        let existing: SSHServer
        switch mode {
        case .add: existing = SSHServer()
        case .edit(let server): existing = server
        }
        serverID = existing.id
        _name = State(initialValue: existing.name)
        _host = State(initialValue: existing.host)
        _port = State(initialValue: String(existing.port))
        _username = State(initialValue: existing.username)
        _authMethod = State(initialValue: existing.authMethod == .agentOrDefault ? .key : existing.authMethod)
        _group = State(initialValue: existing.group)
        _notes = State(initialValue: existing.notes)
        _hasExistingPassword = State(initialValue: KeychainService.hasPassword(for: existing.id))
        _hasExistingKey = State(initialValue: KeychainService.hasPrivateKeyText(for: existing.id))
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
        NavigationStack {
            Form {
                Section("Identificação") {
                    TextField("Nome", text: $name)
                    TextField("Grupo (opcional)", text: $group)
                }

                Section("Conexão") {
                    TextField("Host / IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Porta", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Usuário", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Autenticação") {
                    Picker("Método", selection: $authMethod) {
                        Text(SSHAuthMethod.key.label).tag(SSHAuthMethod.key)
                        Text(SSHAuthMethod.password.label).tag(SSHAuthMethod.password)
                    }
                    .pickerStyle(.segmented)

                    if authMethod == .password {
                        SecureField(hasExistingPassword ? "Nova senha (deixe em branco para manter)" : "Senha", text: $password)
                        Text("A senha fica só no Keychain do iPhone/iPad, nunca em texto puro.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if authMethod == .key {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Importar arquivo de chave…", systemImage: "doc.badge.plus")
                        }
                        TextField(hasExistingKey ? "Chave já importada — cole aqui para substituir" : "Ou cole o conteúdo da chave privada aqui", text: $privateKeyText, axis: .vertical)
                            .lineLimit(4...8)
                            .font(.system(.footnote, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Senha da chave (se houver)", text: $keyPassphrase)
                        Text("Só chaves Ed25519 e RSA no formato OpenSSH (o padrão do `ssh-keygen`) são suportadas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let importError {
                            Text(importError).font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section("Notas") {
                    TextField("Notas (opcional)", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(isEditing ? "Editar servidor" : "Novo servidor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Salvar" : "Adicionar") { save() }
                        .disabled(!isValid)
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item]) { result in
                importKeyFile(result)
            }
        }
    }

    private func importKeyFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Não foi possível acessar o arquivo selecionado."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                privateKeyText = try String(contentsOf: url, encoding: .utf8)
                importError = nil
            } catch {
                importError = "Não foi possível ler o arquivo: \(error.localizedDescription)"
            }
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
            identityFilePath: "",
            group: group.trimmingCharacters(in: .whitespaces),
            notes: notes
        )
        if case .edit(let original) = mode {
            server.isFavorite = original.isFavorite
        }

        if authMethod == .key {
            let trimmedKey = privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                KeychainService.savePrivateKeyText(trimmedKey, for: server.id)
            }
            let trimmedPassphrase = keyPassphrase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPassphrase.isEmpty {
                KeychainService.saveKeyPassphrase(trimmedPassphrase, for: server.id)
            }
        }

        let newPassword = password.isEmpty ? nil : password
        onSave(server, newPassword)
    }
}
