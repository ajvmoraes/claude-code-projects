import SwiftUI

@main
struct SSHLauncherApp: App {
    @StateObject private var store = ServerStore()

    var body: some Scene {
        WindowGroup("SSH Launcher") {
            ContentView()
                .environmentObject(store)
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
        }
    }
}

extension Notification.Name {
    static let sshLauncherNewServer = Notification.Name("sshLauncherNewServer")
}
