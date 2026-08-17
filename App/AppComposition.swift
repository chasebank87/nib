import AppKit
import Combine
import NibDomain
import NibServices

@MainActor
final class AppComposition: ObservableObject {
    static let shared = AppComposition()

    let settings: SettingsStoring
    let appearance: AppearanceController
    let editorSettings: EditorSettingsController
    let recovery: DocumentRecoveryStoring
    let languageServer: LanguageServerClienting
    let secrets: SecretStoring
    let aiProvider: AIProvider

    init(
        settings: SettingsStoring = UserDefaultsSettingsStore(),
        appearanceApplier: AppearanceApplying = AppKitAppearanceApplier(),
        languageServer: LanguageServerClienting = UnconfiguredLanguageServer(),
        secrets: SecretStoring = InMemorySecretStore(),
        aiProvider: AIProvider = UnconfiguredAIProvider.instance,
        recovery: DocumentRecoveryStoring? = nil
    ) {
        self.settings = settings
        self.languageServer = languageServer
        self.secrets = secrets
        self.aiProvider = aiProvider
        if let recovery {
            self.recovery = recovery
        } else {
            self.recovery = (try? FileRecoveryStore()) ?? MemoryRecoveryStore()
        }
        editorSettings = EditorSettingsController(store: settings)
        let stored = settings.string(for: AppearanceController.preferenceKey)
        let preference = stored.flatMap(AppearancePreference.init(rawValue:)) ?? .system
        appearance = AppearanceController(
            preference: preference,
            store: settings,
            applier: appearanceApplier
        )
        appearance.apply()
    }

    func resolvedTheme() -> Theme {
        switch appearance.preference {
        case .light:
            return .nibLight
        case .dark:
            return .nibDark
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .nibDark : .nibLight
        }
    }
}
