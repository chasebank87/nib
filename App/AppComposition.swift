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
    let languageDetector: LanguageDetecting
    let syntaxHighlighter: SyntaxHighlighting
    let themeCatalog: ThemeCatalog

    init(
        settings: SettingsStoring = UserDefaultsSettingsStore(),
        appearanceApplier: AppearanceApplying = AppKitAppearanceApplier(),
        languageServer: LanguageServerClienting = UnconfiguredLanguageServer(),
        secrets: SecretStoring = InMemorySecretStore(),
        aiProvider: AIProvider = UnconfiguredAIProvider.instance,
        recovery: DocumentRecoveryStoring? = nil,
        languageDetector: LanguageDetecting = DefaultLanguageDetector(),
        syntaxHighlighter: SyntaxHighlighting = CompositeSyntaxHighlighter(),
        themeCatalog: ThemeCatalog? = nil
    ) {
        self.settings = settings
        self.languageServer = languageServer
        self.secrets = secrets
        self.aiProvider = aiProvider
        self.languageDetector = languageDetector
        self.syntaxHighlighter = syntaxHighlighter
        ThemeCatalog.ensureUserDirectoryExists()
        if let themeCatalog {
            self.themeCatalog = themeCatalog
        } else {
            self.themeCatalog = ThemeCatalog(
                builtIn: Theme.builtIn,
                extra: ThemeCatalog.loadUserThemes()
            )
        }
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
        if let pinned = editorSettings.settings.themeID,
           let theme = themeCatalog.theme(id: pinned)
        {
            return theme
        }
        switch appearance.preference {
        case .light:
            return themeCatalog.theme(id: Theme.nibLight.id) ?? .nibLight
        case .dark:
            return themeCatalog.theme(id: Theme.nibDark.id) ?? .nibDark
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
                ? (themeCatalog.theme(id: Theme.nibDark.id) ?? .nibDark)
                : (themeCatalog.theme(id: Theme.nibLight.id) ?? .nibLight)
        }
    }
}
