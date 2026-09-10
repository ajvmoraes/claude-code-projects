import SwiftUI
import AppKit

struct OpenSession: Identifiable {
    let id = UUID()
    var server: SSHServer
    var title: String
}

struct ContentView: View {
    @EnvironmentObject var store: ServerStore
    @EnvironmentObject var appearance: TerminalAppearance

    @State private var searchText = ""
    @State private var selectedServerID: SSHServer.ID?
    @State private var sessions: [OpenSession] = []
    @State private var selectedSessionID: UUID?

    @State private var showingAddSheet = false
    @State private var editingServer: SSHServer?
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
        return dict.keys.sorted().map { key in
            (key, dict[key]!.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .onReceive(NotificationCenter.default.publisher(for: .sshLauncherNewServer)) { _ in
            showingAddSheet = true
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
        .sheet(isPresented: $showingExport) {
            ExportView(servers: store.servers, onDone: { showingExport = false })
        }
        .sheet(isPresented: $showingImport) {
            ImportView(onImport: { document, passphrase in
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
                if let server = serverPendingDeletion { store.delete(server) }
                serverPendingDeletion = nil
            }
        } message: {
            Text("Isso remove \"\(serverPendingDeletion?.name ?? "")\" e a senha salva (se houver). Não afeta sessões já abertas.")
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

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedServerID) {
            if !favorites.isEmpty {
                Section("Favoritos") {
                    ForEach(favorites) { server in
                        ServerRow(server: server, isOpen: sessions.contains { $0.server.id == server.id })
                            .tag(server.id)
                            .onTapGesture { connect(to: server) }
                            .contextMenu { contextMenu(for: server) }
                    }
                }
            }
            ForEach(groupedRest, id: \.group) { entry in
                Section(entry.group) {
                    ForEach(entry.servers) { server in
                        ServerRow(server: server, isOpen: sessions.contains { $0.server.id == server.id })
                            .tag(server.id)
                            .onTapGesture { connect(to: server) }
                            .contextMenu { contextMenu(for: server) }
                    }
                }
            }
            if store.servers.isEmpty {
                Text("Nenhum servidor cadastrado ainda.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Buscar servidor")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LogoFooterView()
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Label("Novo servidor", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for server: SSHServer) -> some View {
        Button("Conectar") { connect(to: server) }
        Button("Abrir nova sessão") { openNewSession(for: server) }
        Divider()
        Button(server.isFavorite ? "Remover dos favoritos" : "Marcar como favorito") {
            store.toggleFavorite(server)
        }
        Button("Editar…") { editingServer = server }
        Button("Duplicar") { store.duplicate(server) }
        Button("Copiar comando SSH") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(server.shellCommandDescription(), forType: .string)
        }
        Divider()
        Button("Excluir…", role: .destructive) { serverPendingDeletion = server }
    }

    // MARK: - Detail (tabs + terminal)

    private var detail: some View {
        VStack(spacing: 0) {
            if !sessions.isEmpty {
                tabStrip
                Divider()
            }
            ZStack {
                ForEach(sessions) { session in
                    TerminalHostView(
                        server: session.server,
                        appearance: appearance,
                        onTitleChange: { title in updateTitle(for: session.id, title: title) },
                        onProcessExited: { _ in closeSession(id: session.id) }
                    )
                    .id(session.id)
                    .opacity(session.id == selectedSessionID ? 1 : 0)
                    .allowsHitTesting(session.id == selectedSessionID)
                }
                if sessions.isEmpty {
                    WelcomeView(hasServers: !store.servers.isEmpty, onNewServer: { showingAddSheet = true })
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { appearance.zoomOut() } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Diminuir fonte do terminal (⌘−)")
                Button { appearance.zoomIn() } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Aumentar fonte do terminal (⌘+)")
                Divider()
                Button { showingImport = true } label: {
                    Label("Importar", systemImage: "square.and.arrow.down")
                }
                Button { showingExport = true } label: {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .disabled(store.servers.isEmpty)
            }
        }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sessions) { session in
                    TabChip(
                        title: session.title,
                        isSelected: session.id == selectedSessionID,
                        onSelect: { selectedSessionID = session.id },
                        onClose: { closeSession(id: session.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Session management

    private func connect(to server: SSHServer) {
        if let existing = sessions.first(where: { $0.server.id == server.id }) {
            selectedSessionID = existing.id
            return
        }
        openNewSession(for: server)
    }

    private func openNewSession(for server: SSHServer) {
        let session = OpenSession(server: server, title: server.name)
        sessions.append(session)
        selectedSessionID = session.id
    }

    private func closeSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = sessions.last?.id
        }
    }

    private func updateTitle(for id: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].title = title
    }
}

private struct TabChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? SwiftUI.Color.accentColor.opacity(0.18) : SwiftUI.Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: onSelect)
    }
}
