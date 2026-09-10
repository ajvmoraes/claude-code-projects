import SwiftUI
import UIKit

/// iOS counterpart of the Mac app's terminal appearance settings (font family/size,
/// text/background color), persisted the same way via UserDefaults.
@MainActor
final class TerminalAppearance: ObservableObject {
    static let availableFonts = ["SF Mono", "Menlo", "Courier New"]
    static let defaultFontName = "SF Mono"
    static let defaultFontSize: Double = 15
    static let minFontSize: Double = 10
    static let maxFontSize: Double = 26

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
            ?? SwiftUI.Color(uiColor: .label)
        backgroundColor = defaults.string(forKey: Keys.background).flatMap(SwiftUI.Color.init(hexString:))
            ?? SwiftUI.Color(uiColor: .systemBackground)
    }

    var uiFont: UIFont {
        if fontName == "SF Mono" {
            return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        return UIFont(name: fontName, size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    func zoomIn() { fontSize = min(Self.maxFontSize, fontSize + 1) }
    func zoomOut() { fontSize = max(Self.minFontSize, fontSize - 1) }

    func resetToDefault() {
        fontName = Self.defaultFontName
        fontSize = Self.defaultFontSize
        foregroundColor = SwiftUI.Color(uiColor: .label)
        backgroundColor = SwiftUI.Color(uiColor: .systemBackground)
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
        let color = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }
}
