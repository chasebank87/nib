import Foundation
import NibDomain
import NibServices
import Testing

struct TextDiffTests {
    @Test func buildsInsertionAndDeletionLines() {
        let lines = TextDiff.lines(before: "a\nb\nc", after: "a\nx\nc")
        #expect(lines.contains(where: { $0.kind == .deletion && $0.text == "b" }))
        #expect(lines.contains(where: { $0.kind == .insertion && $0.text == "x" }))
        #expect(TextDiff.unified(before: "hi", after: "hi") == " hi")
    }
}

struct GhostSuggestionTests {
    @Test func firstWordKeepsLeadingWhitespace() {
        let ghost = GhostSuggestion(text: " mock_complete()", anchorUTF16: 3)
        #expect(ghost.firstWord == " mock_complete()")
        let multi = GhostSuggestion(text: "foo bar", anchorUTF16: 0)
        #expect(multi.firstWord == "foo")
    }
}

struct AIProviderKindTests {
    @Test func endpointDefaultsForLocalAndCloudProviders() {
        let ollama = AIProviderEndpoint.resolve(kind: .ollama, baseURLString: nil, model: nil)
        #expect(ollama.baseURL.absoluteString.contains("11434"))
        #expect(ollama.model == "llama3.2")
        #expect(AIProviderKind.ollama.requiresAPIKey == false)

        let openRouter = AIProviderEndpoint.resolve(kind: .openRouter, baseURLString: nil, model: "anthropic/claude-sonnet-4")
        #expect(openRouter.baseURL.absoluteString.contains("openrouter.ai"))
        #expect(openRouter.model == "anthropic/claude-sonnet-4")
        #expect(openRouter.extraHeaders["X-Title"] == "nib")
        #expect(AIProviderKind.openRouter.requiresAPIKey)

        let lm = AIProviderEndpoint.resolve(
            kind: .lmStudio,
            baseURLString: "http://127.0.0.1:1234/v1",
            model: "qwen2.5-coder"
        )
        #expect(lm.model == "qwen2.5-coder")
        #expect(AIProviderKind.lmStudio.requiresAPIKey == false)
    }

    @Test func migratesLegacyHTTPFlag() {
        let json = #"{"enableHTTPProvider":true,"fontSize":13}"#
        let settings = EditorSettings.decoded(from: json)
        #expect(settings.aiProviderKind == .openAI)
        #expect(settings.enableHTTPProvider)
    }
}

struct MockAIProviderPhase4Tests {
    @Test func inlineCompleteReturnsSuggestion() async throws {
        let provider = MockAIProvider()
        let suggestion = try await provider.inlineComplete(
            InlineCompletionRequest(
                prefix: "print(",
                disclosure: ContextDisclosure()
            )
        )
        #expect(suggestion?.text == ")")
    }

    @Test func fixDiagnosticProducesEdit() async throws {
        let response = try await MockAIProvider().complete(
            AIRequest(
                instruction: "Fix this diagnostic",
                selectedText: "x = 1",
                diagnosticsText: "L1:1 error: demo",
                disclosure: ContextDisclosure(selectedCharacterCount: 5, includesDiagnostics: true)
            )
        )
        #expect(response.proposedEdit?.contains("fixed:") == true)
    }

    @Test func askAboutFileStaysLocal() async throws {
        let response = try await MockAIProvider().complete(
            AIRequest(
                instruction: "Ask about this file",
                selectedText: "excerpt",
                fileText: "line1\nline2\n",
                disclosure: ContextDisclosure(selectedCharacterCount: 12)
            )
        )
        #expect(response.proposedEdit == nil)
        #expect(response.text.contains("Mock file overview"))
    }
}

struct HTTPOpenAICompatibleProviderTests {
    @Test func parsesNibEditFence() async throws {
        let store = InMemorySecretStore()
        try store.store(account: KeychainSecretStore.providerAPIKeyAccount, secret: Data("sk-test".utf8))
        let auth = HTTPAuthProbe()
        let session = StubHTTPSession(
            body: """
            {"choices":[{"message":{"content":"Done.\\n```nib-edit\\nhello()\\n```"}}]}
            """,
            auth: auth
        )
        let provider = HTTPOpenAICompatibleProvider(
            endpoint: AIProviderEndpoint(kind: .openAI),
            secrets: store,
            session: session
        )
        let response = try await provider.complete(
            AIRequest(
                instruction: "Edit this selection",
                selectedText: "hi",
                disclosure: ContextDisclosure(selectedCharacterCount: 2)
            )
        )
        #expect(response.proposedEdit == "hello()")
        #expect(auth.value?.contains("Bearer sk-test") == true)
    }

    @Test func ollamaAllowsMissingKey() async throws {
        let auth = HTTPAuthProbe()
        let session = StubHTTPSession(
            body: #"{"choices":[{"message":{"content":"ok"}}]}"#,
            auth: auth
        )
        let provider = HTTPOpenAICompatibleProvider(
            endpoint: AIProviderEndpoint(kind: .ollama),
            secrets: InMemorySecretStore(),
            session: session
        )
        let response = try await provider.complete(
            AIRequest(
                instruction: "Explain",
                selectedText: "x",
                disclosure: ContextDisclosure(selectedCharacterCount: 1)
            )
        )
        #expect(response.text == "ok")
        #expect(auth.value == nil)
    }

    @Test func openRouterSendsExtraHeaders() async throws {
        let store = InMemorySecretStore()
        try store.store(account: KeychainSecretStore.providerAPIKeyAccount, secret: Data("or-key".utf8))
        let auth = HTTPAuthProbe()
        let session = StubHTTPSession(
            body: #"{"choices":[{"message":{"content":"routed"}}]}"#,
            auth: auth
        )
        let provider = HTTPOpenAICompatibleProvider(
            endpoint: AIProviderEndpoint(kind: .openRouter),
            secrets: store,
            session: session
        )
        _ = try await provider.complete(
            AIRequest(
                instruction: "Explain",
                selectedText: "x",
                disclosure: ContextDisclosure(selectedCharacterCount: 1)
            )
        )
        #expect(auth.headers["HTTP-Referer"]?.contains("github.com") == true)
        #expect(auth.headers["X-Title"] == "nib")
    }

    @Test func missingKeyFailsForOpenAI() async {
        let provider = HTTPOpenAICompatibleProvider(
            endpoint: AIProviderEndpoint(kind: .openAI),
            secrets: InMemorySecretStore(),
            session: StubHTTPSession(body: "{}", auth: HTTPAuthProbe())
        )
        do {
            _ = try await provider.complete(
                AIRequest(
                    instruction: "Explain",
                    selectedText: "x",
                    disclosure: ContextDisclosure(selectedCharacterCount: 1)
                )
            )
            #expect(Bool(false), "expected missingAPIKey")
        } catch let error as AIProviderError {
            #expect(error == .missingAPIKey)
        } catch {
            #expect(Bool(false), "unexpected error \(error)")
        }
    }
}

struct RoutedAIProviderTests {
    @Test func prefersMockWhenKindIsMock() async throws {
        let store = InMemorySecretStore()
        try store.store(account: KeychainSecretStore.providerAPIKeyAccount, secret: Data("sk".utf8))
        let routing = AIProviderRoutingState(kind: .mock)
        let routed = RoutedAIProvider(
            mock: MockAIProvider(),
            secrets: store,
            routing: routing,
            session: StubHTTPSession(body: "{}", auth: HTTPAuthProbe())
        )
        let response = try await routed.complete(
            AIRequest(
                instruction: "Explain this selection",
                selectedText: "abc",
                disclosure: ContextDisclosure(selectedCharacterCount: 3)
            )
        )
        #expect(response.text.contains("Mock explanation"))
    }

    @Test func routesToOllamaWithoutKey() async throws {
        let routing = AIProviderRoutingState(kind: .ollama, model: "llama3.2")
        let routed = RoutedAIProvider(
            mock: MockAIProvider(),
            secrets: InMemorySecretStore(),
            routing: routing,
            session: StubHTTPSession(
                body: #"{"choices":[{"message":{"content":"local"}}]}"#,
                auth: HTTPAuthProbe()
            )
        )
        let response = try await routed.complete(
            AIRequest(
                instruction: "Explain this selection",
                selectedText: "abc",
                disclosure: ContextDisclosure(selectedCharacterCount: 3)
            )
        )
        #expect(response.text == "local")
        #expect(routed.displayName == "Ollama")
    }
}

struct AgentOrchestratorTests {
    @Test @MainActor func runsPlanAndProducesProposal() async {
        let orchestrator = AgentOrchestrator()
        let permissions = ToolPermissionController(grants: [.readCurrentFile, .sendToProvider])
        let plan = orchestrator.makeImproveSelectionPlan(
            selection: "print(1)",
            selectionRange: 0..<8,
            diagnostics: [
                Diagnostic(message: "demo", severity: .warning, line: 1, column: 1),
            ],
            filePath: nil,
            includeGit: false
        )
        #expect(plan.steps.count == 4)
        let finished = await orchestrator.run(
            plan: plan,
            selection: "print(1)",
            diagnostics: [
                Diagnostic(message: "demo", severity: .warning, line: 1, column: 1),
            ],
            filePath: nil,
            permissions: permissions,
            provider: MockAIProvider(),
            allowPromptGrant: true
        )
        #expect(finished.proposedEdit?.contains("mock-improved") == true)
        #expect(finished.steps.contains(where: { $0.status == .failed }) == false)
        #expect(permissions.has(.readDiagnostics))
    }

    @Test @MainActor func denialStopsPlan() async {
        let orchestrator = AgentOrchestrator()
        let permissions = ToolPermissionController(grants: [])
        let plan = orchestrator.makeImproveSelectionPlan(
            selection: "x",
            selectionRange: 0..<1,
            diagnostics: [],
            filePath: nil,
            includeGit: false
        )
        let finished = await orchestrator.run(
            plan: plan,
            selection: "x",
            diagnostics: [],
            filePath: nil,
            permissions: permissions,
            provider: MockAIProvider(),
            allowPromptGrant: false
        )
        #expect(finished.proposedEdit == nil)
        #expect(finished.steps.contains(where: { $0.status == .failed }))
        #expect(finished.summary?.contains("permission denied") == true)
    }
}

struct WorkspaceFileSearchTests {
    @Test func findsMatchingFileNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nib-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("HelloWorld.swift")
        try "print(1)".write(to: target, atomically: true, encoding: .utf8)
        let hits = try WorkspaceFileSearch.search(query: "helloworld", startingAt: root.path)
        #expect(hits.contains(where: { $0.fileName == "HelloWorld.swift" }))
    }
}

private final class HTTPAuthProbe: @unchecked Sendable {
    var value: String?
    var headers: [String: String] = [:]
}

private struct StubHTTPSession: HTTPSessioning {
    var body: String
    let auth: HTTPAuthProbe

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        auth.value = request.value(forHTTPHeaderField: "Authorization")
        var captured: [String: String] = [:]
        if let referer = request.value(forHTTPHeaderField: "HTTP-Referer") {
            captured["HTTP-Referer"] = referer
        }
        if let title = request.value(forHTTPHeaderField: "X-Title") {
            captured["X-Title"] = title
        }
        auth.headers = captured
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}
