import SwiftUI
import AppKit

/// Hosts one embedded, fully interactive SSH session (a real pty running `/usr/bin/ssh`)
/// using the vendored SwiftTerm `LocalProcessTerminalView`. One instance per open tab.
struct TerminalHostView: NSViewRepresentable {
    let server: SSHServer
    var appearance: TerminalAppearance
    var onTitleChange: (String) -> Void = { _ in }
    var onProcessExited: (Int32?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTitleChange: onTitleChange, onProcessExited: onProcessExited)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        context.coordinator.terminalView = view
        applyAppearance(to: view)

        let storedPassword = server.authMethod == .password ? KeychainService.readPassword(for: server.id) : nil
        view.startProcess(executable: "/usr/bin/ssh", args: server.buildSSHArguments())

        if let storedPassword, !storedPassword.isEmpty {
            context.coordinator.armPasswordAutoType(password: storedPassword)
        }
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyAppearance(to: nsView)
    }

    private func applyAppearance(to view: LocalProcessTerminalView) {
        let desiredFont = appearance.nsFont
        if view.font != desiredFont {
            view.font = desiredFont
        }
        let fg = NSColor(appearance.foregroundColor)
        if view.nativeForegroundColor != fg {
            view.nativeForegroundColor = fg
        }
        let bg = NSColor(appearance.backgroundColor)
        if view.nativeBackgroundColor != bg {
            view.nativeBackgroundColor = bg
        }
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        coordinator.cancelPasswordAutoType()
        nsView.terminate()
    }

    @MainActor
    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        weak var terminalView: LocalProcessTerminalView?
        let onTitleChange: (String) -> Void
        let onProcessExited: (Int32?) -> Void

        private var passwordToSend: String?
        private var pollTimer: Timer?
        private var pollTicksRemaining = 0

        init(onTitleChange: @escaping (String) -> Void, onProcessExited: @escaping (Int32?) -> Void) {
            self.onTitleChange = onTitleChange
            self.onProcessExited = onProcessExited
        }

        /// Best-effort convenience: watches the visible screen for a "password:" style
        /// prompt for a few seconds after connecting and types the stored password once.
        /// If it never fires (unusual prompt wording, MFA, etc.) the user just types the
        /// password by hand — this is a real interactive terminal, nothing is blocked.
        func armPasswordAutoType(password: String) {
            passwordToSend = password
            pollTicksRemaining = 40 // ~20s at 0.5s interval
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    self?.pollForPasswordPrompt(timer: timer)
                }
            }
        }

        func cancelPasswordAutoType() {
            pollTimer?.invalidate()
            pollTimer = nil
            passwordToSend = nil
        }

        private func pollForPasswordPrompt(timer: Timer) {
            pollTicksRemaining -= 1
            guard let password = passwordToSend, let terminalView, let terminal = terminalView.terminal else {
                timer.invalidate()
                return
            }
            if pollTicksRemaining <= 0 {
                timer.invalidate()
                pollTimer = nil
                return
            }
            let rows = terminal.rows
            let cols = terminal.cols
            guard rows > 0, cols > 0 else { return }
            let lastRow = max(0, rows - 1)
            let screenText = terminal.getText(
                start: Position(col: 0, row: 0),
                end: Position(col: cols, row: lastRow)
            ).lowercased()

            if screenText.contains("password:") || screenText.contains("senha:") {
                terminalView.send(txt: password + "\r")
                passwordToSend = nil
                timer.invalidate()
                pollTimer = nil
            }
        }

        // MARK: - LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            onTitleChange(title)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            onProcessExited(exitCode)
        }
    }
}
