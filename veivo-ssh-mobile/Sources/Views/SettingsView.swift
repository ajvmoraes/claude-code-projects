import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appearance: TerminalAppearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Section {
                    Button("Restaurar padrão") { appearance.resetToDefault() }
                }
            }
            .navigationTitle("Preferências")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") { dismiss() }
                }
            }
        }
    }
}
