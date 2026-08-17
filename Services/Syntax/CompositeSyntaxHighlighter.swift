import Foundation
import NibDomain

/// Prefers Tree-sitter grammars, then regex fallbacks, else empty (plain text).
public struct CompositeSyntaxHighlighter: SyntaxHighlighting, Sendable {
    private let treeSitter: TreeSitterHighlighter
    private let regex: RegexSyntaxHighlighter

    public init(
        treeSitter: TreeSitterHighlighter = TreeSitterHighlighter(),
        regex: RegexSyntaxHighlighter = RegexSyntaxHighlighter()
    ) {
        self.treeSitter = treeSitter
        self.regex = regex
    }

    public func highlights(for text: String, language: LanguageDescriptor) async throws -> [SyntaxCapture] {
        if language.id == LanguageDescriptor.plainText.id {
            return []
        }
        if TreeSitterHighlighter.supports(language.id) {
            return try await treeSitter.highlights(for: text, language: language)
        }
        if RegexSyntaxHighlighter.supports(language.id) {
            return try await regex.highlights(for: text, language: language)
        }
        return []
    }
}
