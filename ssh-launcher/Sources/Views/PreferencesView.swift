import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appearance: TerminalAppearance

    var body: some View {
        Form {
            Section("Fonte do terminal") {
                Picker("Fonte", selection: $appearance.fontName) {
                    ForEach(TerminalAppearance.availableFonts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Stepper(value: $appearance.fontSize, in: TerminalAppearance.minFontSize...TerminalAppearance.maxFontSize, step: 1) {
                    Text("Tamanho: \(Int(appearance.fontSize)) pt")
                }
                HStack {
                    Text("Atalhos: ⌘+ aumenta, ⌘− diminui, ⌘0 restaura")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Cores") {
                ColorPicker("Texto", selection: $appearance.foregroundColor, supportsOpacity: false)
                ColorPicker("Fundo", selection: $appearance.backgroundColor, supportsOpacity: false)
            }

            Section("Pré-visualização") {
                Text("usuario@servidor:~$ ls -la")
                    .font(.custom(appearance.fontName, size: appearance.fontSize))
                    .foregroundStyle(appearance.foregroundColor)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(appearance.backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Section {
                Button("Restaurar padrão") { appearance.resetToDefault() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
    }
}
