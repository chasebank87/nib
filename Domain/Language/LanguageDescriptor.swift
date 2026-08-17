import Foundation

public struct LanguageDescriptor: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var extensions: [String]
    public var filenames: [String]
    public var shebangs: [String]

    public init(
        id: String,
        name: String,
        extensions: [String] = [],
        filenames: [String] = [],
        shebangs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.extensions = extensions
        self.filenames = filenames
        self.shebangs = shebangs
    }

    public static let plainText = LanguageDescriptor(id: "plaintext", name: "Plain Text")

    public static let priorityLanguages: [LanguageDescriptor] = [
        LanguageDescriptor(
            id: "typescript",
            name: "TypeScript",
            extensions: ["ts", "tsx", "mts", "cts"]
        ),
        LanguageDescriptor(
            id: "javascript",
            name: "JavaScript",
            extensions: ["js", "jsx", "mjs", "cjs"],
            shebangs: ["node"]
        ),
        LanguageDescriptor(id: "json", name: "JSON", extensions: ["json", "jsonc"]),
        LanguageDescriptor(id: "markdown", name: "Markdown", extensions: ["md", "markdown"]),
        LanguageDescriptor(
            id: "python",
            name: "Python",
            extensions: ["py"],
            shebangs: ["python", "python3"]
        ),
        LanguageDescriptor(id: "swift", name: "Swift", extensions: ["swift"]),
        LanguageDescriptor(id: "zig", name: "Zig", extensions: ["zig", "zon"]),
        LanguageDescriptor(id: "sql", name: "SQL", extensions: ["sql"]),
        LanguageDescriptor(id: "yaml", name: "YAML", extensions: ["yml", "yaml"]),
        LanguageDescriptor(
            id: "shell",
            name: "Shell",
            extensions: ["sh", "bash", "zsh"],
            filenames: [".bashrc", ".zshrc"],
            shebangs: ["sh", "bash", "zsh"]
        ),
    ]
}

/// TODO(NIB-007): Implement using extension, filename, shebang, then user override.
public protocol LanguageDetecting: Sendable {
    func detect(url: URL?, firstLine: String?, overrideID: String?) -> LanguageDescriptor
}

/// TODO(NIB-008): Tree-sitter incremental highlighting mapped to theme syntax tokens.
public protocol SyntaxHighlighting: Sendable {
    func highlights(for text: String, language: LanguageDescriptor) async throws -> [SyntaxCapture]
}

public struct SyntaxCapture: Equatable, Sendable {
    public var range: Range<Int>
    public var scope: String

    public init(range: Range<Int>, scope: String) {
        self.range = range
        self.scope = scope
    }
}
