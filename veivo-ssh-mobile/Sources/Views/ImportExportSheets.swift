import SwiftUI
import UniformTypeIdentifiers

struct ExportSheetView: View {
    let servers: [SSHServer]
    var onDone: () -> Void

    @State private var includePasswords = false
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var exportURL: URL?
    @State private var errorMessage: String?

    private var canExport: Bool {
        includePasswords ? (!passphrase.isEmpty && passphrase == confirmPassphrase) : true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Gera um arquivo .json com os \(servers.count) servidor(es) cadastrados. Chaves privadas não são incluídas — apenas host, porta, usuário e demais dados do servidor.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Incluir senhas salvas (criptografadas)", isOn: $includePasswords)
                    if includePasswords {
                        SecureField("Senha de proteção do backup", text: $passphrase)
                        SecureField("Confirmar senha", text: $confirmPassphrase)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Compartilhar / Salvar arquivo", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Gerar arquivo") { generate() }
                            .disabled(!canExport)
                    }
                }
            }
            .navigationTitle("Exportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { onDone() }
                }
            }
        }
    }

    private func generate() {
        let document = ExportImportService.makeBackup(servers: servers, passphrase: includePasswords ? passphrase : nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("veivo-ssh-backup.json")
        do {
            try ExportImportService.encodeToFile(document, url: url)
            exportURL = url
            errorMessage = nil
        } catch {
            errorMessage = "Falha ao gerar: \(error.localizedDescription)"
        }
    }
}

struct ImportSheetView: View {
    var onImport: (BackupDocument, String?) -> Void
    var onDone: () -> Void

    @State private var showingFileImporter = false
    @State private var pickedDocument: BackupDocument?
    @State private var passphrase = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Button("Escolher arquivo de backup…") { showingFileImporter = true }

                if let doc = pickedDocument {
                    Text("\(doc.entries.count) servidor(es) encontrados.")
                    if doc.kdfSaltBase64 != nil {
                        SecureField("Senha do backup (para restaurar senhas)", text: $passphrase)
                        Text("Deixe em branco para importar só os servidores, sem as senhas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("Importar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        if let doc = pickedDocument {
                            onImport(doc, passphrase.isEmpty ? nil : passphrase)
                        }
                        onDone()
                    }
                    .disabled(pickedDocument == nil)
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Não foi possível acessar o arquivo."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                pickedDocument = try ExportImportService.decodeFromFile(url: url)
                errorMessage = nil
            } catch {
                errorMessage = "Arquivo inválido: \(error.localizedDescription)"
            }
        }
    }
}
