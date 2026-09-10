import SwiftUI

@main
struct SSHLauncherApp: App {
    @StateObject private var store = ServerStore()
    @StateObject private var appearance = TerminalAppearance()

    var body: some Scene {
        WindowGroup("VEIVO SSH") {
            ContentView()
                .environmentObject(store)
                .environmentObject(appearance)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Novo servidor…") {
                    NotificationCenter.default.post(name: .sshLauncherNewServer, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Terminal") {
                Button("Aumentar fonte") { appearance.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Diminuir fonte") { appearance.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Tamanho padrão da fonte") { appearance.resetToDefault() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appearance)
        }
    }
}

extension Notification.Name {
    static let sshLauncherNewServer = Notification.Name("sshLauncherNewServer")
}
