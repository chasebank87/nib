import NibDomain
import SwiftUI

public struct EditorSettingsView: View {
    @Binding var settings: EditorSettings

    public init(settings: Binding<EditorSettings>) {
        _settings = settings
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
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
        .onChange(of: settings) { _, newValue in
            let sanitized = newValue.sanitized()
            if sanitized != newValue {
                settings = sanitized
            }
        }
    }
}
