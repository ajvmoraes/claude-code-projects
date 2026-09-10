import SwiftUI

struct ServerRowView: View {
    let server: SSHServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).fontWeight(.medium)
                Text(server.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if server.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct WelcomeView: View {
    let hasServers: Bool
    let onNewServer: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(hasServers ? "Selecione um servidor" : "Nenhum servidor cadastrado")
                .font(.title3)
                .foregroundStyle(.secondary)
            if !hasServers {
                Button("Adicionar servidor", action: onNewServer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
