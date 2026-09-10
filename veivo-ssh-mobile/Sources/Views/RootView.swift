import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: ServerStore
    @EnvironmentObject var appearance: TerminalAppearance

    @State private var searchText = ""
    @State private var selectedServerID: SSHServer.ID?
    @State private var showingAddSheet = false
    @State private var editingServer: SSHServer?
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var serverPendingDeletion: SSHServer?
    @State private var lastImportSummary: String?

    private var filteredServers: [SSHServer] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return store.servers }
        let q = searchText.lowercased()
        return store.servers.filter {
            $0.name.lowercased().contains(q) ||
            $0.host.lowercased().contains(q) ||
            $0.username.lowercased().contains(q) ||
            $0.group.lowercased().contains(q)
        }
    }

    private var favorites: [SSHServer] {
        filteredServers.filter(\.isFavorite).sorted { $0.name < $1.name }
    }

    private var groupedRest: [(group: String, servers: [SSHServer])] {
        let rest = filteredServers.filter { !$0.isFavorite }
        let dict = Dictionary(grouping: rest) { $0.group.isEmpty ? "Servidores" : $0.group }
        return dict.keys.sorted().map { key in (key, dict[key]!.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let id = selectedServerID, let server = store.servers.first(where: { $0.id == id }) {
                TerminalConnectionView(server: server)
                    .id(server.id)
            } else {
                WelcomeView(hasServers: !store.servers.isEmpty, onNewServer: { showingAddSheet = true })
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerFormView(mode: .add, onSave: { server, password in
                store.add(server)
                if let password { KeychainService.savePassword(password, for: server.id) }
                showingAddSheet = false
            }, onCancel: { showingAddSheet = false })
        }
        .sheet(item: $editingServer) { server in
            ServerFormView(mode: .edit(server), onSave: { updated, password in
                store.update(updated)
                if let password { KeychainService.savePassword(password, for: updated.id) }
                editingServer = nil
            }, onCancel: { editingServer = nil })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingExport) {
            ExportSheetView(servers: store.servers, onDone: { showingExport = false })
        }
        .sheet(isPresented: $showingImport) {
            ImportSheetView(onImport: { document, passphrase in
                let result = ExportImportService.restore(document: document, passphrase: passphrase)
                store.merge(imported: result.imported)
                lastImportSummary = "\(result.imported.count) servidor(es) importado(s). Senhas restauradas: \(result.passwordsRestored)."
            }, onDone: { showingImport = false })
        }
        .alert("Excluir servidor?", isPresented: Binding(
            get: { serverPendingDeletion != nil },
            set: { if !$0 { serverPendingDeletion = nil } }
        )) {
            Button("Cancelar", role: .cancel) { serverPendingDeletion = nil }
            Button("Excluir", role: .destructive) {
                if let server = serverPendingDeletion {
                    if selectedServerID == server.id { selectedServerID = nil }
                    store.delete(server)
                }
                serverPendingDeletion = nil
            }
        } message: {
            Text("Isso remove \"\(serverPendingDeletion?.name ?? "")\" e as credenciais salvas.")
        }
        .alert("Importação concluída", isPresented: Binding(
            get: { lastImportSummary != nil },
            set: { if !$0 { lastImportSummary = nil } }
        )) {
            Button("OK") { lastImportSummary = nil }
        } message: {
            Text(lastImportSummary ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $selectedServerID) {
            if !favorites.isEmpty {
                Section("Favoritos") {
                    ForEach(favorites) { server in
                        ServerRowView(server: server)
                            .tag(server.id)
                            .swipeActions(edge: .trailing) { swipeActions(for: server) }
                            .contextMenu { contextMenu(for: server) }
                    }
                }
            }
            ForEach(groupedRest, id: \.group) { entry in
                Section(entry.group) {
                    ForEach(entry.servers) { server in
                        ServerRowView(server: server)
                            .tag(server.id)
                            .swipeActions(edge: .trailing) { swipeActions(for: server) }
                            .contextMenu { contextMenu(for: server) }
                    }
                }
            }
            if store.servers.isEmpty {
                Text("Nenhum servidor cadastrado ainda.")
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LogoFooterView()
        }
        .searchable(text: $searchText, prompt: "Buscar servidor")
        .navigationTitle("VEIVO SSH")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingAddSheet = true } label: {
                        Label("Novo servidor…", systemImage: "plus")
                    }
                    Button { showingImport = true } label: {
                        Label("Importar…", systemImage: "square.and.arrow.down")
                    }
                    Button { showingExport = true } label: {
                        Label("Exportar…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.servers.isEmpty)
                    Divider()
                    Button { showingSettings = true } label: {
                        Label("Preferências…", systemImage: "textformat.size")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func swipeActions(for server: SSHServer) -> some View {
        Button(role: .destructive) { serverPendingDeletion = server } label: {
            Label("Excluir", systemImage: "trash")
        }
        Button { editingServer = server } label: {
            Label("Editar", systemImage: "pencil")
        }
        .tint(.blue)
    }

    @ViewBuilder
    private func contextMenu(for server: SSHServer) -> some View {
        Button(server.isFavorite ? "Remover dos favoritos" : "Marcar como favorito") {
            store.toggleFavorite(server)
        }
        Button("Editar…") { editingServer = server }
        Button("Duplicar") { store.duplicate(server) }
        Divider()
        Button("Excluir…", role: .destructive) { serverPendingDeletion = server }
    }
}
