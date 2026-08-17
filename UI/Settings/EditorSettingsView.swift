import NibDomain
import NibServices
import SwiftUI

public struct EditorSettingsView: View {
    @Binding var settings: EditorSettings
    var themes: [Theme]
    var secrets: SecretStoring
    @State private var apiKeyDraft = ""
    @State private var apiKeyStatus = "No key stored"
    @State private var apiKeyMessage: String?

    public init(
        settings: Binding<EditorSettings>,
        themes: [Theme] = Theme.builtIn,
        secrets: SecretStoring = InMemorySecretStore()
    ) {
        _settings = settings
        self.themes = themes
        self.secrets = secrets
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
            Toggle("HTTP AI provider (when key stored)", isOn: $settings.enableHTTPProvider)
            Toggle("Inline ghost text", isOn: $settings.enableInlineGhostText)
            Picker("Theme", selection: Binding(
                get: { settings.themeID ?? "" },
                set: { settings.themeID = $0.isEmpty ? nil : $0 }
            )) {
                Text("Automatic").tag("")
                ForEach(themes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }

            Section("AI provider key") {
                Text(apiKeyStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                SecureField("API key", text: $apiKeyDraft)
                HStack {
                    Button("Save Key") { saveAPIKey() }
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Clear Key", role: .destructive) { clearAPIKey() }
                }
                if let apiKeyMessage {
                    Text(apiKeyMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 680)
        .onAppear(perform: refreshAPIKeyStatus)
        .onChange(of: settings) { _, newValue in
            let sanitized = newValue.sanitized()
            if sanitized != newValue {
                settings = sanitized
            }
        }
    }

    private func refreshAPIKeyStatus() {
        do {
            if let data = try secrets.retrieve(account: KeychainSecretStore.providerAPIKeyAccount),
               data.isEmpty == false
            {
                apiKeyStatus = "Key stored (\(data.count) bytes)"
            } else {
                apiKeyStatus = "No key stored"
            }
        } catch {
            apiKeyStatus = "Unable to read key status"
            apiKeyMessage = "Keychain error"
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let data = trimmed.data(using: .utf8) else { return }
        do {
            try secrets.store(account: KeychainSecretStore.providerAPIKeyAccount, secret: data)
            apiKeyDraft = ""
            apiKeyMessage = "Saved to Keychain"
            refreshAPIKeyStatus()
        } catch {
            apiKeyMessage = "Save failed"
        }
    }

    private func clearAPIKey() {
        do {
            try secrets.delete(account: KeychainSecretStore.providerAPIKeyAccount)
            apiKeyDraft = ""
            apiKeyMessage = "Cleared"
            refreshAPIKeyStatus()
        } catch {
            apiKeyMessage = "Clear failed"
        }
    }
}
