import SwiftUI

/// Owns the lifecycle of one SSH connection for as long as this screen is on-screen —
/// created when the user taps a server, torn down when they navigate back.
struct TerminalConnectionView: View {
    let server: SSHServer
    @EnvironmentObject var appearance: TerminalAppearance
    @StateObject private var session: SSHTerminalSession

    init(server: SSHServer) {
        self.server = server
        _session = StateObject(wrappedValue: SSHTerminalSession(server: server))
    }

    var body: some View {
        ZStack {
            TerminalScreenView(server: server, session: session, appearance: appearance)
                .ignoresSafeArea(edges: .bottom)

            if case .connecting = session.state {
                overlay {
                    ProgressView("Conectando a \(server.host)…")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            } else if case .failed(let message) = session.state {
                overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Falha ao conectar")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func overlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            SwiftUI.Color.black.opacity(0.6).ignoresSafeArea()
            content()
        }
    }
}
