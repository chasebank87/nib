import Foundation
import NibDomain

/// Live routing configuration for which AI backend to use.
public final class AIProviderRoutingState: @unchecked Sendable {
    public var kind: AIProviderKind
    public var model: String
    public var baseURLString: String

    public init(
        kind: AIProviderKind = .mock,
        model: String = "",
        baseURLString: String = ""
    ) {
        self.kind = kind
        self.model = model
        self.baseURLString = baseURLString
    }

    public func apply(_ settings: EditorSettings) {
        kind = settings.aiProviderKind
        model = settings.aiModel
        baseURLString = settings.aiBaseURL
    }
}

/// Chooses Mock vs a configured OpenAI-compatible endpoint from routing state.
public struct RoutedAIProvider: AIProvider {
    public var id: String { active.id }
    public var displayName: String { active.displayName }
    public var capabilities: AICapabilities { active.capabilities }

    private let mock: AIProvider
    private let secrets: SecretStoring
    private let routing: AIProviderRoutingState
    private let session: any HTTPSessioning
    private let account: String

    public init(
        mock: AIProvider = MockAIProvider(),
        secrets: SecretStoring,
        routing: AIProviderRoutingState,
        session: any HTTPSessioning = URLSessionHTTPClient(),
        account: String = KeychainSecretStore.providerAPIKeyAccount
    ) {
        self.mock = mock
        self.secrets = secrets
        self.routing = routing
        self.session = session
        self.account = account
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        try await active.complete(request)
    }

    public func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        try await active.inlineComplete(request)
    }

    private var active: AIProvider {
        let kind = routing.kind
        guard kind != .mock else { return mock }
        let endpoint = AIProviderEndpoint.resolve(
            kind: kind,
            baseURLString: routing.baseURLString,
            model: routing.model
        )
        return HTTPOpenAICompatibleProvider(
            endpoint: endpoint,
            secrets: secrets,
            session: session,
            account: account
        )
    }
}

/// Compatibility shim for older call sites/tests.
@available(*, deprecated, renamed: "AIProviderRoutingState")
public typealias HTTPProviderPreference = AIProviderRoutingState

public extension AIProviderRoutingState {
    var isEnabled: Bool {
        get { kind != .mock }
        set { kind = newValue ? (kind == .mock ? .openAI : kind) : .mock }
    }

    convenience init(isEnabled: Bool) {
        self.init(kind: isEnabled ? .openAI : .mock)
    }
}
