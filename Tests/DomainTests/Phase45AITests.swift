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
        let provider = HTTPOpenAICompatibleProvider(secrets: store, session: session)
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

    @Test func missingKeyFails() async {
        let provider = HTTPOpenAICompatibleProvider(
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
    @Test func prefersMockWhenHTTPDisabled() async throws {
        let store = InMemorySecretStore()
        try store.store(account: KeychainSecretStore.providerAPIKeyAccount, secret: Data("sk".utf8))
        let routed = RoutedAIProvider(
            mock: MockAIProvider(),
            http: HTTPOpenAICompatibleProvider(
                secrets: store,
                session: StubHTTPSession(body: "{}", auth: HTTPAuthProbe())
            ),
            secrets: store,
            prefersHTTP: { false }
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
            filePath: "/tmp/a.py"
        )
        #expect(plan.steps.count == 4)
        let finished = await orchestrator.run(
            plan: plan,
            selection: "print(1)",
            diagnostics: [
                Diagnostic(message: "demo", severity: .warning, line: 1, column: 1),
            ],
            filePath: "/tmp/a.py",
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
            filePath: nil
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

private final class HTTPAuthProbe: @unchecked Sendable {
    var value: String?
}

private struct StubHTTPSession: HTTPSessioning {
    var body: String
    let auth: HTTPAuthProbe

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        auth.value = request.value(forHTTPHeaderField: "Authorization")
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}
