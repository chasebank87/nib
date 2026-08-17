import Foundation
import NibDomain

/// Minimal URLSession seam for HTTP AI tests without touching the network.
public protocol HTTPSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionHTTPClient: HTTPSessioning {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// OpenAI-compatible chat completions adapter (OpenAI, OpenRouter, LM Studio, Ollama, …).
public struct HTTPOpenAICompatibleProvider: AIProvider {
    public var id: String
    public var displayName: String
    public var capabilities: AICapabilities {
        AICapabilities(inlineCompletion: true, chat: true, tools: false)
    }

    public var baseURL: URL
    public var model: String
    public var requiresAPIKey: Bool
    public var extraHeaders: [String: String]
    private let secrets: SecretStoring
    private let session: any HTTPSessioning
    private let account: String

    public init(
        endpoint: AIProviderEndpoint,
        secrets: SecretStoring,
        session: any HTTPSessioning = URLSessionHTTPClient(),
        account: String = KeychainSecretStore.providerAPIKeyAccount
    ) {
        self.id = endpoint.kind.rawValue
        self.displayName = endpoint.kind.displayName
        self.baseURL = endpoint.baseURL
        self.model = endpoint.model
        self.requiresAPIKey = endpoint.kind.requiresAPIKey
        self.extraHeaders = endpoint.extraHeaders
        self.secrets = secrets
        self.session = session
        self.account = account
    }

    public init(
        secrets: SecretStoring,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "gpt-4o-mini",
        session: any HTTPSessioning = URLSessionHTTPClient(),
        account: String = KeychainSecretStore.providerAPIKeyAccount,
        id: String = AIProviderKind.openAI.rawValue,
        displayName: String = AIProviderKind.openAI.displayName,
        requiresAPIKey: Bool = true,
        extraHeaders: [String: String] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.model = model
        self.requiresAPIKey = requiresAPIKey
        self.extraHeaders = extraHeaders
        self.secrets = secrets
        self.session = session
        self.account = account
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let key = try optionalAPIKey()
        let body = ChatCompletionBody(model: model, messages: [
            .init(role: "system", content: """
            You are a coding assistant inside the nib macOS editor.
            Reply briefly. When proposing an edit, put the full replacement text \
            inside a single fenced code block labeled nib-edit.
            """),
            .init(role: "user", content: userPrompt(for: request)),
        ])
        let data = try await post(path: "chat/completions", body: body, apiKey: key)
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, content.isEmpty == false else {
            throw AIProviderError.invalidResponse
        }
        return AIResponse(text: content, proposedEdit: extractNibEdit(from: content))
    }

    public func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        let key = try optionalAPIKey()
        let body = ChatCompletionBody(model: model, messages: [
            .init(
                role: "system",
                content: "Return only the continuation text to insert at the caret. No markdown."
            ),
            .init(
                role: "user",
                content: """
                Language: \(request.languageID)
                Prefix:
                \(request.prefix.suffix(2_000))
                Suffix:
                \(request.suffix.prefix(500))
                """
            ),
        ])
        let data = try await post(path: "chat/completions", body: body, apiKey: key)
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard var content = decoded.choices.first?.message.content else { return nil }
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.isEmpty == false else { return nil }
        return GhostSuggestion(text: content, anchorUTF16: (request.prefix as NSString).length)
    }

    private func optionalAPIKey() throws -> String? {
        if let data = try secrets.retrieve(account: account),
           let key = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           key.isEmpty == false
        {
            return key
        }
        if requiresAPIKey {
            throw AIProviderError.missingAPIKey
        }
        return nil
    }

    private func userPrompt(for request: AIRequest) -> String {
        var parts: [String] = [
            "Instruction: \(request.instruction)",
            "Selection:\n\(request.selectedText)",
        ]
        if let path = request.disclosure.filePath {
            parts.append("Path: \(path)")
        }
        if let fileText = request.fileText, request.disclosure.includesRepositoryContext == false {
            parts.append("File excerpt:\n\(fileText.prefix(8_000))")
        }
        if let diagnostics = request.diagnosticsText, request.disclosure.includesDiagnostics {
            parts.append("Diagnostics:\n\(diagnostics)")
        }
        return parts.joined(separator: "\n\n")
    }

    private func post<Body: Encodable>(path: String, body: Body, apiKey: String?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            throw AIProviderError.httpStatus(http.statusCode)
        }
        return data
    }

    private func extractNibEdit(from content: String) -> String? {
        guard let start = content.range(of: "```nib-edit") else { return nil }
        let after = content[start.upperBound...]
        guard let end = after.range(of: "```") else { return nil }
        var block = String(after[..<end.lowerBound])
        if block.hasPrefix("\n") {
            block.removeFirst()
        }
        return block.trimmingCharacters(in: .newlines)
    }
}

private struct ChatCompletionBody: Encodable {
    var model: String
    var messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    var role: String
    var content: String
}

private struct ChatCompletionResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
    }
}
