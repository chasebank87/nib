import Foundation
import NibDomain

/// Regex fallback for priority languages without a Tree-sitter grammar yet.
public struct RegexSyntaxHighlighter: SyntaxHighlighting, Sendable {
    public init() {}

    public func highlights(for text: String, language: LanguageDescriptor) async throws -> [SyntaxCapture] {
        try Task.checkCancellation()
        guard let rules = Self.rules[language.id] else {
            throw SyntaxHighlightError.unsupportedLanguage
        }
        return try await Task.detached(priority: .utility) {
            Self.apply(rules: rules, to: text)
        }.value
    }

    public static func supports(_ languageID: String) -> Bool {
        rules[languageID] != nil
    }

    private struct Rule {
        var pattern: String
        var scope: String
        var options: NSRegularExpression.Options
    }

    private static let rules: [String: [Rule]] = [
        "swift": [
            Rule(pattern: #"//.*|/\*[\s\S]*?\*/"#, scope: "comment", options: []),
            Rule(pattern: #""(?:\\.|[^"\\])*""#, scope: "string", options: []),
            Rule(pattern: #"\b\d[\d_]*(\.\d[\d_]*)?\b"#, scope: "number", options: []),
            Rule(
                pattern: #"\b(actor|as|await|break|case|catch|class|continue|default|defer|deinit|do|else|enum|extension|fallthrough|false|fileprivate|final|for|func|guard|if|import|in|internal|is|let|nil|open|operator|private|protocol|public|repeat|return|self|static|struct|switch|throw|throws|true|try|typealias|var|where|while|async|some|any|throws|rethrows)\b"#,
                scope: "keyword",
                options: []
            ),
            Rule(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#, scope: "type", options: []),
            Rule(pattern: #"\b[a-z_][A-Za-z0-9_]*\s*(?=\()"#, scope: "function", options: []),
        ],
        "javascript": jsRules,
        "typescript": jsRules,
        "zig": [
            Rule(pattern: #"//.*"#, scope: "comment", options: []),
            Rule(pattern: #""(?:\\.|[^"\\])*""#, scope: "string", options: []),
            Rule(pattern: #"\b\d[\w.]*\b"#, scope: "number", options: []),
            Rule(
                pattern: #"\b(const|var|fn|pub|try|return|if|else|while|for|switch|struct|enum|error|defer|async|await|break|continue|unreachable|null|undefined|true|false)\b"#,
                scope: "keyword",
                options: []
            ),
        ],
        "shell": [
            Rule(pattern: #"#.*"#, scope: "comment", options: []),
            Rule(pattern: #"'[^']*'|"[^"]*""#, scope: "string", options: []),
            Rule(
                pattern: #"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|in|fi)\b"#,
                scope: "keyword",
                options: []
            ),
        ],
        "yaml": [
            Rule(pattern: #"#.*"#, scope: "comment", options: []),
            Rule(pattern: #":\s*.+$"#, scope: "string", options: [.anchorsMatchLines]),
            Rule(pattern: #"^\s*[\w.-]+\s*(?=:)"#, scope: "variable", options: [.anchorsMatchLines]),
        ],
        "sql": [
            Rule(pattern: #"--.*"#, scope: "comment", options: []),
            Rule(pattern: #"'([^']|'')*'"#, scope: "string", options: []),
            Rule(
                pattern: #"\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|TABLE|INDEX|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|NULL|AS|INTO|VALUES|SET|GROUP|ORDER|BY|LIMIT|OFFSET)\b"#,
                scope: "keyword",
                options: [.caseInsensitive]
            ),
        ],
        "dockerfile": [
            Rule(pattern: #"#.*"#, scope: "comment", options: []),
            Rule(
                pattern: #"\b(FROM|RUN|CMD|LABEL|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b"#,
                scope: "keyword",
                options: []
            ),
            Rule(pattern: #""[^"]*"|'[^']*'"#, scope: "string", options: []),
        ],
    ]

    private static let jsRules: [Rule] = [
        Rule(pattern: #"//.*|/\*[\s\S]*?\*/"#, scope: "comment", options: []),
        Rule(pattern: #"`(?:\\.|[^`\\])*`|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\""#, scope: "string", options: []),
        Rule(pattern: #"\b\d[\d_]*(\.\d[\d_]*)?\b"#, scope: "number", options: []),
        Rule(
            pattern: #"\b(async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|false|finally|for|from|function|if|import|in|instanceof|let|new|null|return|static|super|switch|this|throw|true|try|typeof|var|void|while|with|yield|of|enum|implements|interface|package|private|protected|public|type)\b"#,
            scope: "keyword",
            options: []
        ),
        Rule(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#, scope: "type", options: []),
        Rule(pattern: #"\b[a-z_][A-Za-z0-9_]*\s*(?=\()"#, scope: "function", options: []),
    ]

    private static func apply(rules: [Rule], to text: String) -> [SyntaxCapture] {
        var captures: [SyntaxCapture] = []
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else {
                continue
            }
            for match in regex.matches(in: text, options: [], range: full) {
                let range = match.range
                guard range.location != NSNotFound, range.length > 0 else { continue }
                captures.append(
                    SyntaxCapture(
                        utf16Range: range.location..<(range.location + range.length),
                        scope: rule.scope
                    )
                )
            }
        }
        return captures
    }
}
