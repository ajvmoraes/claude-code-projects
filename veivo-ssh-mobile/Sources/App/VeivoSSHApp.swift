import SwiftUI

@main
struct VeivoSSHApp: App {
    @StateObject private var store = ServerStore()
    @StateObject private var appearance = TerminalAppearance()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appearance)
        }
    }
}
