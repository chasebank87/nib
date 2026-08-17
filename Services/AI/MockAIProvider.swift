import Foundation
import NibDomain

/// Offline canned provider for Phase 4. Never leaves the device.
public struct MockAIProvider: AIProvider {
    public var id: String { "mock" }
    public var displayName: String { "Mock" }
    public var capabilities: AICapabilities {
        AICapabilities(inlineCompletion: true, chat: true, tools: false)
    }

    public init() {}

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let preview = request.selectedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .joined(separator: "\n")
        let path = request.disclosure.filePath.map { " in `\($0)`" } ?? ""
        let lowered = request.instruction.lowercased()

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
}
