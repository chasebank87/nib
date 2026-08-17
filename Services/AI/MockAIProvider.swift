import Foundation
import NibDomain

/// Offline canned provider for Phase 4. Never leaves the device.
public struct MockAIProvider: AIProvider {
    public var id: String { "mock" }
    public var displayName: String { "Mock" }
    public var capabilities: AICapabilities {
        AICapabilities(inlineCompletion: true, chat: true, tools: true)
    }

    public init() {}

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let preview = request.selectedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .joined(separator: "\n")
        let path = request.disclosure.filePath.map { " in `\($0)`" } ?? ""
        let lowered = request.instruction.lowercased()

        if lowered.contains("fix") || lowered.contains("diagnostic") {
            let fixed = mockFix(request.selectedText, diagnostics: request.diagnosticsText)
            return AIResponse(
                text: """
                Mock diagnostic fix\(path).

                Review the proposed replacement, then Apply or Reject.
                """,
                proposedEdit: fixed
            )
        }

        if lowered.contains("ask about") || lowered.contains("this file") {
            let excerpt = (request.fileText ?? request.selectedText)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .prefix(12)
                .joined(separator: "\n")
            return AIResponse(
                text: """
                Mock file overview\(path):

                \(excerpt)

                This response is local-only. No network call was made.
                """,
                proposedEdit: nil
            )
        }

        if lowered.contains("generate") {
            let generated = mockGenerate(request.selectedText)
            return AIResponse(
                text: """
                Mock generation\(path).

                Review the proposed insertion, then Apply or Reject.
                """,
                proposedEdit: generated
            )
        }

        if lowered.contains("edit") {
            let edited = mockEdit(request.selectedText)
            return AIResponse(
                text: """
                Mock edit proposal\(path) (\(request.disclosure.selectedCharacterCount) characters).

                Review the proposed replacement, then Apply or Reject. Nothing was written yet.
                """,
                proposedEdit: edited
            )
        }

        if lowered.contains("document") || lowered.contains("docstring") || lowered.contains("comment") {
            let documented = mockDocument(request.selectedText)
            return AIResponse(
                text: """
                Mock documentation proposal\(path).

                Review the proposed replacement, then Apply or Reject.
                """,
                proposedEdit: documented
            )
        }

        return AIResponse(
            text: """
            Mock explanation\(path) (\(request.disclosure.selectedCharacterCount) characters):

            \(preview)

            This response is local-only. No network call was made.
            """,
            proposedEdit: nil
        )
    }

    public func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        let prefix = request.prefix
        guard prefix.isEmpty == false else { return nil }
        let lastLine = prefix.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let trimmed = lastLine.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("(") {
            return GhostSuggestion(text: ")", anchorUTF16: (prefix as NSString).length)
        }
        if trimmed.hasSuffix("{") {
            return GhostSuggestion(text: " }", anchorUTF16: (prefix as NSString).length)
        }
        if trimmed.hasSuffix("\"") == false, trimmed.contains("\"") == false,
           trimmed.lowercased().hasPrefix("print") || trimmed.lowercased().hasPrefix("func ")
        {
            return GhostSuggestion(text: " // mock", anchorUTF16: (prefix as NSString).length)
        }
        if trimmed.isEmpty == false, trimmed.hasSuffix(" ") == false {
            return GhostSuggestion(text: "_mock", anchorUTF16: (prefix as NSString).length)
        }
        return GhostSuggestion(text: "mock_complete()", anchorUTF16: (prefix as NSString).length)
    }

    private func mockEdit(_ selected: String) -> String {
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return selected }
        if trimmed.contains("\n") {
            return "// mock-improved\n" + selected
        }
        return "/* mock-improved */ \(trimmed)"
    }

    private func mockDocument(_ selected: String) -> String {
        let first = selected.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? selected
        return "/// Mock documentation for: \(first.trimmingCharacters(in: .whitespaces))\n" + selected
    }

    private func mockFix(_ selected: String, diagnostics: String?) -> String {
        let note = diagnostics?.split(separator: "\n").first.map(String.init) ?? "unknown issue"
        if selected.contains("\n") {
            return "// fixed: \(note)\n" + selected
        }
        return "/* fixed: \(note) */ \(selected)"
    }

    private func mockGenerate(_ selected: String) -> String {
        let seed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if seed.isEmpty {
            return "// generated by mock\nfunc generated() {}\n"
        }
        return selected + "\n// generated follow-up\n"
    }
}
