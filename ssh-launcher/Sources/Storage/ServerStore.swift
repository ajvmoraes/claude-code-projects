import Foundation
import Combine

@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [SSHServer] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SSHLauncher", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("servers.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([SSHServer].self, from: data) {
            servers = decoded
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(servers) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ server: SSHServer) {
        servers.append(server)
        save()
    }

    func update(_ server: SSHServer) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        save()
    }

    func delete(_ server: SSHServer) {
        servers.removeAll { $0.id == server.id }
        KeychainService.deletePassword(for: server.id)
        KeychainService.deletePrivateKeyText(for: server.id)
        KeychainService.deleteKeyPassphrase(for: server.id)
        save()
    }

    func duplicate(_ server: SSHServer) {
        var copy = server
        copy.id = UUID()
        copy.name = server.name + " (cópia)"
        servers.append(copy)
        save()
    }

    func toggleFavorite(_ server: SSHServer) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index].isFavorite.toggle()
        save()
    }

    /// Merges imported servers into the current list, skipping exact-ID duplicates that
    /// already exist (re-importing the same backup twice is a no-op for those entries).
    func merge(imported: [SSHServer]) {
        let existingIDs = Set(servers.map(\.id))
        for server in imported where !existingIDs.contains(server.id) {
            servers.append(server)
        }
        save()
    }
}
