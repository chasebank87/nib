import Foundation
import NibDomain
import NibServices
import Testing

struct FindReplaceTests {
    @Test func literalCaseInsensitiveAndWholeWord() throws {
        let text = "Foo foo food"
        let all = try FindReplaceEngine.findAll(
            in: text,
            options: FindOptions(query: "foo", caseSensitive: false)
        )
        #expect(all.count == 3)

        let words = try FindReplaceEngine.findAll(
            in: text,
            options: FindOptions(query: "foo", caseSensitive: false, wholeWord: true)
        )
        #expect(words.count == 2)
    }

    @Test func regexReplaceAll() throws {
        let text = "a1 b22 c3"
        let result = try FindReplaceEngine.replaceAll(
            in: text,
            options: FindOptions(
                query: #"\d+"#,
                replacement: "#",
                useRegularExpression: true
            )
        )
        #expect(result.text == "a# b# c#")
        #expect(result.count == 3)
    }

    @Test func invalidRegexSurfaces() {
        do {
            _ = try FindReplaceEngine.findAll(
                in: "abc",
                options: FindOptions(query: "(", useRegularExpression: true)
            )
            Issue.record("expected invalid regex to throw")
        } catch FindError.invalidRegularExpression {
            // expected
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}

struct DocumentCapabilityTests {
    @Test func thresholdsDisableFeatures() {
        #expect(DocumentCapabilities.forByteCount(100).liveHighlighting)
        let reduced = DocumentCapabilities.forByteCount(DocumentLimits.reducedFeatureByteCount)
        #expect(reduced.liveHighlighting == false)
        #expect(reduced.wrapLines == false)
        let huge = DocumentCapabilities.forByteCount(DocumentLimits.hardWarningByteCount)
        #expect(huge.lineNumbers == false)
    }
}

struct SyntaxHighlighterTests {
    private var queryDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Services/Syntax/Queries")
    }

    @Test func treeSitterJSONProducesCaptures() async throws {
        let highlighter = TreeSitterHighlighter(queryDirectory: queryDirectory)
        let captures = try await highlighter.highlights(
            for: #"{"name": "nib", "count": 2}"#,
            language: LanguageDescriptor(id: "json", name: "JSON", extensions: ["json"])
        )
        #expect(captures.isEmpty == false)
        #expect(captures.contains { $0.scope == "string" || $0.scope.hasPrefix("string") })
    }

    @Test func regexSwiftFallbackColorsKeywords() async throws {
        let highlighter = RegexSyntaxHighlighter()
        let captures = try await highlighter.highlights(
            for: "func hello() { return 1 }",
            language: LanguageDescriptor(id: "swift", name: "Swift", extensions: ["swift"])
        )
        #expect(captures.contains { $0.scope == "keyword" })
    }
}
