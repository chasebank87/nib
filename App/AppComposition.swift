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
    let languageServers: LanguageServerController
    let secrets: SecretStoring
    let aiProvider: AIProvider
    let toolPermissions: ToolPermissionController
    let agentOrchestrator: AgentOrchestrator
    let languageDetector: LanguageDetecting
    let syntaxHighlighter: SyntaxHighlighting
    let themeCatalog: ThemeCatalog

    private let aiRouting: AIProviderRoutingState
    private var settingsObservation: AnyCancellable?

    init(
        settings: SettingsStoring = UserDefaultsSettingsStore(),
        appearanceApplier: AppearanceApplying = AppKitAppearanceApplier(),
        languageServers: LanguageServerController? = nil,
        secrets: SecretStoring = KeychainSecretStore(),
        aiProvider: AIProvider? = nil,
        toolPermissions: ToolPermissionController? = nil,
        recovery: DocumentRecoveryStoring? = nil,
        languageDetector: LanguageDetecting = DefaultLanguageDetector(),
        syntaxHighlighter: SyntaxHighlighting = CompositeSyntaxHighlighter(),
        themeCatalog: ThemeCatalog? = nil
    ) {
        self.settings = settings
        self.languageServers = languageServers ?? LanguageServerController()
        self.secrets = secrets
        self.toolPermissions = toolPermissions ?? ToolPermissionController()
        self.agentOrchestrator = AgentOrchestrator()
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
        let routing = AIProviderRoutingState()
        routing.apply(editorSettings.settings)
        self.aiRouting = routing
        if let aiProvider {
            self.aiProvider = aiProvider
        } else {
            self.aiProvider = RoutedAIProvider(
                mock: MockAIProvider(),
                secrets: secrets,
                routing: routing
            )
        }
        let stored = settings.string(for: AppearanceController.preferenceKey)
        let preference = stored.flatMap(AppearancePreference.init(rawValue:)) ?? .system
        appearance = AppearanceController(
            preference: preference,
            store: settings,
            applier: appearanceApplier
        )
        appearance.apply()

        let servers = self.languageServers
        let initialSettings = editorSettings.settings
        settingsObservation = editorSettings.$settings
            .sink { newSettings in
                routing.apply(newSettings)
                Task { @MainActor in
                    await servers.applySettings(newSettings)
                }
            }
        Task { @MainActor in
            await servers.applySettings(initialSettings)
        }
    }

    /// Active LSP client (demo FakeLSP or unconfigured no-op).
    var languageServer: LanguageServerClienting {
        languageServers.client
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
