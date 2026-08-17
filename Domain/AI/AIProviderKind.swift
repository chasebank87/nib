import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case mock
    case openAI
    case openRouter
    case lmStudio
    case ollama

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mock: return "Mock (offline)"
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .lmStudio: return "LM Studio"
        case .ollama: return "Ollama"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .mock, .lmStudio, .ollama: return false
        case .openAI, .openRouter: return true
        }
    }

    public var defaultBaseURLString: String {
        switch self {
        case .mock: return ""
        case .openAI: return "https://api.openai.com/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .lmStudio: return "http://127.0.0.1:1234/v1"
        case .ollama: return "http://127.0.0.1:11434/v1"
        }
    }

    public var defaultModel: String {
        switch self {
        case .mock: return ""
        case .openAI: return "gpt-4o-mini"
        case .openRouter: return "openrouter/auto"
        case .lmStudio: return "local-model"
        case .ollama: return "llama3.2"
        }
    }

    public var helpText: String {
        switch self {
        case .mock:
            return "Local canned responses. Nothing leaves the device."
        case .openAI:
            return "Official OpenAI Chat Completions API. Requires an API key."
        case .openRouter:
            return "OpenRouter OpenAI-compatible API. Requires an OpenRouter key."
        case .lmStudio:
            return "Local LM Studio server (default http://127.0.0.1:1234/v1). Key optional."
        case .ollama:
            return "Local Ollama OpenAI-compatible endpoint (default http://127.0.0.1:11434/v1)."
        }
    }
}

public struct AIProviderEndpoint: Equatable, Sendable {
    public var kind: AIProviderKind
    public var baseURL: URL
    public var model: String
    public var extraHeaders: [String: String]

    public init(
        kind: AIProviderKind,
        baseURL: URL? = nil,
        model: String? = nil,
        extraHeaders: [String: String] = [:]
    ) {
        self.kind = kind
        if let baseURL {
            self.baseURL = baseURL
        } else if let url = URL(string: kind.defaultBaseURLString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://127.0.0.1")!
        }
        let resolvedModel = (model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = resolvedModel.isEmpty ? kind.defaultModel : resolvedModel
        var headers = extraHeaders
        if kind == .openRouter {
            headers["HTTP-Referer"] = headers["HTTP-Referer"] ?? "https://github.com/chasebank87/nib"
            headers["X-Title"] = headers["X-Title"] ?? "nib"
        }
        self.extraHeaders = headers
    }

    public static func resolve(
        kind: AIProviderKind,
        baseURLString: String?,
        model: String?
    ) -> AIProviderEndpoint {
        let trimmedURL = baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)
        return AIProviderEndpoint(kind: kind, baseURL: url, model: model)
    }
}
