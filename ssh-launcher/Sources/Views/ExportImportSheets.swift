import SwiftUI
import AppKit

struct ExportView: View {
    let servers: [SSHServer]
    var onDone: () -> Void

    @State private var includePasswords = false
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?

    private var canExport: Bool {
        if includePasswords {
            return !passphrase.isEmpty && passphrase == confirmPassphrase
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exportar configurações")
                .font(.headline)

            Text("Gera um único arquivo .json com todos os \(servers.count) servidor(es) cadastrados: host, porta, usuário, grupo e demais opções. Chaves SSH em si não são copiadas — apenas o caminho que cada servidor referencia.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle("Incluir senhas salvas (criptografadas)", isOn: $includePasswords)

            if includePasswords {
                SecureField("Senha de proteção do backup", text: $passphrase)
                SecureField("Confirmar senha", text: $confirmPassphrase)
                Text("As senhas dos servidores ficam criptografadas dentro do arquivo com essa senha. Guarde-a: sem ela não é possível recuperá-las na importação.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { onDone() }
                Button("Exportar…") { exportFile() }
                    .disabled(!canExport)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func exportFile() {
        let document = ExportImportService.makeBackup(
            servers: servers,
            passphrase: includePasswords ? passphrase : nil
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ssh-launcher-backup.json"
        panel.message = "Salvar backup dos servidores"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ExportImportService.encodeToFile(document, url: url)
            onDone()
        } catch {
            errorMessage = "Falha ao salvar: \(error.localizedDescription)"
        }
    }
}

struct ImportView: View {
    var onImport: (BackupDocument, String?) -> Void
    var onDone: () -> Void

    @State private var pickedURL: URL?
    @State private var pickedDocument: BackupDocument?
    @State private var passphrase = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Importar configurações")
                .font(.headline)

            Text("Selecione um arquivo de backup exportado por este app. Servidores já existentes (mesmo ID) não são duplicados.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button(pickedURL == nil ? "Escolher arquivo…" : (pickedURL!.lastPathComponent)) {
                pickFile()
            }

            if let doc = pickedDocument {
                Text("\(doc.entries.count) servidor(es) encontrados.")
                    .font(.callout)

                if doc.kdfSaltBase64 != nil {
                    SecureField("Senha do backup (para restaurar senhas salvas)", text: $passphrase)
                    Text("Deixe em branco para importar só os servidores, sem restaurar as senhas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { onDone() }
                Button("Importar") { importFile() }
                    .disabled(pickedDocument == nil)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Selecione o arquivo de backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pickedURL = url
        do {
            pickedDocument = try ExportImportService.decodeFromFile(url: url)
            errorMessage = nil
        } catch {
            pickedDocument = nil
            errorMessage = "Arquivo inválido: \(error.localizedDescription)"
        }
    }

    private func importFile() {
        guard let doc = pickedDocument else { return }
        onImport(doc, passphrase.isEmpty ? nil : passphrase)
        onDone()
    }
}
