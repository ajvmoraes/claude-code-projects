import SwiftUI
import UIKit
import SwiftTerm

/// Embeds a real, interactive SSH terminal for one server. The SSH connection itself
/// (via `SSHTerminalSession`) starts as soon as SwiftTerm reports the view's actual
/// column/row count — before that, sizing is unknown and there'd be nothing sensible
/// to size the remote pty to.
struct TerminalScreenView: UIViewRepresentable {
    let server: SSHServer
    @ObservedObject var session: SSHTerminalSession
    var appearance: TerminalAppearance

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero)
        view.terminalDelegate = context.coordinator
        context.coordinator.terminalView = view
        applyAppearance(to: view)

        session.onOutput = { [weak view] bytes in
            DispatchQueue.main.async {
                view?.feed(byteArray: bytes)
            }
        }
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        applyAppearance(to: uiView)
    }

    static func dismantleUIView(_ uiView: TerminalView, coordinator: Coordinator) {
        coordinator.session.close()
    }

    private func applyAppearance(to view: TerminalView) {
        let font = appearance.uiFont
        if view.font != font {
            view.font = font
        }
        let fg = UIColor(appearance.foregroundColor)
        if view.nativeForegroundColor != fg {
            view.nativeForegroundColor = fg
        }
        let bg = UIColor(appearance.backgroundColor)
        if view.nativeBackgroundColor != bg {
            view.nativeBackgroundColor = bg
        }
    }

    @MainActor
    final class Coordinator: NSObject, TerminalViewDelegate {
        let session: SSHTerminalSession
        weak var terminalView: TerminalView?
        private var didStartSession = false

        init(session: SSHTerminalSession) {
            self.session = session
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            guard newCols > 0, newRows > 0 else { return }
            if !didStartSession {
                didStartSession = true
                session.start(cols: newCols, rows: newRows)
            } else {
                session.resize(cols: newCols, rows: newRows)
            }
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            session.send(data)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
