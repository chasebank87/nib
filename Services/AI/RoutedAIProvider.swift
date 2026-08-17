import Foundation
import NibDomain

/// Shared flag for routing between mock and HTTP AI providers.
public final class HTTPProviderPreference: @unchecked Sendable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }
}

/// Chooses Mock vs HTTP based on preference + Keychain presence.
public struct RoutedAIProvider: AIProvider {
    public var id: String { active.id }
    public var displayName: String { active.displayName }
    public var capabilities: AICapabilities { active.capabilities }

    private let mock: AIProvider
    private let http: AIProvider
    private let secrets: SecretStoring
    private let preference: HTTPProviderPreference
    private let account: String

    public init(
        mock: AIProvider = MockAIProvider(),
        http: AIProvider,
        secrets: SecretStoring,
        preference: HTTPProviderPreference,
        account: String = KeychainSecretStore.providerAPIKeyAccount
    ) {
        self.mock = mock
        self.http = http
        self.secrets = secrets
        self.preference = preference
        self.account = account
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        try await active.complete(request)
    }

    public func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        try await active.inlineComplete(request)
    }

    private var active: AIProvider {
        if preference.isEnabled, hasAPIKey {
            return http
        }
        return mock
    }

    private var hasAPIKey: Bool {
        guard let data = try? secrets.retrieve(account: account), data.isEmpty == false else {
            return false
        }
        return true
    }
}
