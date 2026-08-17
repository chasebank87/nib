import Foundation
import NibDomain

/// Offline canned provider for Phase 4. Never leaves the device.
public struct MockAIProvider: AIProvider {
    public var id: String { "mock" }
    public var displayName: String { "Mock" }
    public var capabilities: AICapabilities {
        AICapabilities(inlineCompletion: false, chat: true, tools: false)
    }

    public init() {}

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let preview = request.selectedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(6)
            .joined(separator: "\n")
        let path = request.disclosure.filePath.map { " in `\($0)`" } ?? ""
        let text = """
        Mock explanation\(path) (\(request.disclosure.selectedCharacterCount) characters):

        \(preview)

        This response is local-only. No network call was made. Configure a real provider later to replace the mock.
        """
        return AIResponse(text: text, proposedEdit: nil)
    }
}
