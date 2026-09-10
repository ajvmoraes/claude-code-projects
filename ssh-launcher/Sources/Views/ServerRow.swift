import SwiftUI

struct ServerRow: View {
    let server: SSHServer
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isOpen ? "circle.fill" : "server.rack")
                .foregroundStyle(isOpen ? SwiftUI.Color.green : SwiftUI.Color.secondary)
                .font(.system(size: isOpen ? 8 : 13))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .fontWeight(.medium)
                Text(server.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if server.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
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
            Text(hasServers ? "Selecione um servidor à esquerda para conectar" : "Nenhum servidor cadastrado")
                .font(.title3)
                .foregroundStyle(.secondary)
            if !hasServers {
                Button("Adicionar servidor", action: onNewServer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
