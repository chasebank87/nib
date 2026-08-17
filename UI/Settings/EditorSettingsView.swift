import NibDomain
import SwiftUI

public struct EditorSettingsView: View {
    @Binding var settings: EditorSettings
    var themes: [Theme]

    public init(settings: Binding<EditorSettings>, themes: [Theme] = Theme.builtIn) {
        _settings = settings
        self.themes = themes
    }

    public var body: some View {
        Form {
            Picker("Font", selection: $settings.fontName) {
                ForEach(EditorSettings.recommendedFontNames, id: \.self) { name in
                    Text(EditorSettings.displayName(forFont: name)).tag(name)
                }
            }
            Stepper(value: $settings.fontSize, in: 9...32, step: 1) {
                Text("Size \(Int(settings.fontSize.rounded()))")
            }
            Stepper(value: $settings.lineHeight, in: 1.0...2.5, step: 0.05) {
                Text(String(format: "Line height %.2f", settings.lineHeight))
            }
            Stepper(value: $settings.tabWidth, in: 1...16) {
                Text("Tab width \(settings.tabWidth)")
            }
            Toggle("Insert spaces for Tab", isOn: $settings.insertSpaces)
            Toggle("Wrap lines", isOn: $settings.wrapLines)
            Toggle("Ligatures", isOn: $settings.ligatures)
            Toggle("Line numbers", isOn: $settings.showLineNumbers)
            Toggle("Highlight current line", isOn: $settings.highlightCurrentLine)
            Toggle("Indent guides", isOn: $settings.showIndentGuides)
            Toggle("Language server", isOn: $settings.enableLanguageServer)
            Toggle("Demo language server", isOn: $settings.enableDemoLanguageServer)
                .disabled(settings.enableLanguageServer == false)
            Picker("Theme", selection: Binding(
                get: { settings.themeID ?? "" },
                set: { settings.themeID = $0.isEmpty ? nil : $0 }
            )) {
                Text("Automatic").tag("")
                ForEach(themes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 520)
        .onChange(of: settings) { _, newValue in
            let sanitized = newValue.sanitized()
            if sanitized != newValue {
                settings = sanitized
            }
        }
    }
}
