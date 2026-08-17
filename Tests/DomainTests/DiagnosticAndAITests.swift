import Foundation
import NibDomain
import NibServices
import Testing

struct DiagnosticRangeTests {
    @Test func resolvesLSPRangeToUTF16() {
        let text = "def hello():\n    pass\n"
        let diagnostic = Diagnostic(
            message: "demo",
            severity: .warning,
            line: 1,
            column: 1,
            lspStart: LSPPosition(line: 0, character: 0),
            lspEnd: LSPPosition(line: 0, character: 3)
        ).resolvingUTF16Range(in: text)
        #expect(diagnostic.utf16Range == 0..<3)
    }

    @Test func fallsBackToTokenSpanFromLineColumn() {
        let text = "abcdef"
        let diagnostic = Diagnostic(
            message: "x",
            severity: .error,
            line: 1,
            column: 3
        ).resolvingUTF16Range(in: text)
        #expect(diagnostic.utf16Range?.lowerBound == 2)
        #expect((diagnostic.utf16Range?.count ?? 0) >= 1)
    }
}

struct MockAIProviderTests {
    @Test func explainSelectionStaysLocal() async throws {
        let provider = MockAIProvider()
        let request = AIRequest(
            instruction: "Explain this selection",
            selectedText: "print('hi')",
            disclosure: ContextDisclosure(selectedCharacterCount: 11)
        )
        let response = try await provider.complete(request)
        #expect(response.text.contains("Mock explanation"))
        #expect(response.text.contains("print('hi')"))
        #expect(response.text.contains("local-only"))
    }
}
