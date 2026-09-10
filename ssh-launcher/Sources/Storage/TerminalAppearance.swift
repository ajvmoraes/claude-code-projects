import SwiftUI
import AppKit

/// User-adjustable look of every embedded terminal: font family/size and text/background
/// colors. Shared app-wide (one setting, applied to every open session) and persisted in
/// UserDefaults so it survives relaunches.
@MainActor
final class TerminalAppearance: ObservableObject {
    static let availableFonts = ["SF Mono", "Menlo", "Monaco", "Courier New", "Andale Mono"]
    static let defaultFontName = "SF Mono"
    static let defaultFontSize: Double = 13
    static let minFontSize: Double = 9
    static let maxFontSize: Double = 28

    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: Keys.fontName) }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Keys.fontSize) }
    }
    @Published var foregroundColor: SwiftUI.Color {
        didSet { UserDefaults.standard.set(foregroundColor.toHexString(), forKey: Keys.foreground) }
    }
    @Published var backgroundColor: SwiftUI.Color {
        didSet { UserDefaults.standard.set(backgroundColor.toHexString(), forKey: Keys.background) }
    }

    private enum Keys {
        static let fontName = "terminalFontName"
        static let fontSize = "terminalFontSize"
        static let foreground = "terminalForegroundColor"
        static let background = "terminalBackgroundColor"
    }

    init() {
        let defaults = UserDefaults.standard
        fontName = defaults.string(forKey: Keys.fontName) ?? Self.defaultFontName
        let storedSize = defaults.double(forKey: Keys.fontSize)
        fontSize = storedSize > 0 ? storedSize : Self.defaultFontSize
        foregroundColor = defaults.string(forKey: Keys.foreground).flatMap(SwiftUI.Color.init(hexString:))
            ?? SwiftUI.Color(nsColor: .textColor)
        backgroundColor = defaults.string(forKey: Keys.background).flatMap(SwiftUI.Color.init(hexString:))
            ?? SwiftUI.Color(nsColor: .textBackgroundColor)
    }

    var nsFont: NSFont {
        if fontName == "SF Mono" {
            return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        return NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    func zoomIn() { fontSize = min(Self.maxFontSize, fontSize + 1) }
    func zoomOut() { fontSize = max(Self.minFontSize, fontSize - 1) }

    func resetToDefault() {
        fontName = Self.defaultFontName
        fontSize = Self.defaultFontSize
        foregroundColor = SwiftUI.Color(nsColor: .textColor)
        backgroundColor = SwiftUI.Color(nsColor: .textBackgroundColor)
    }
}

extension SwiftUI.Color {
    init?(hexString: String) {
        let sanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 8, let rgba = UInt32(sanitized, radix: 16) else { return nil }
        let r = Double((rgba >> 24) & 0xFF) / 255
        let g = Double((rgba >> 16) & 0xFF) / 255
        let b = Double((rgba >> 8) & 0xFF) / 255
        let a = Double(rgba & 0xFF) / 255
        self = SwiftUI.Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHexString() -> String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int((color.redComponent * 255).rounded())
        let g = Int((color.greenComponent * 255).rounded())
        let b = Int((color.blueComponent * 255).rounded())
        let a = Int((color.alphaComponent * 255).rounded())
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}
