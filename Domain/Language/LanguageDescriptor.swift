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
        LanguageDescriptor(id: "markdown", name: "Markdown", extensions: ["md", "markdown", "mdown"]),
        LanguageDescriptor(
            id: "python",
            name: "Python",
            extensions: ["py", "pyi"],
            shebangs: ["python", "python3"]
        ),
        LanguageDescriptor(
            id: "swift",
            name: "Swift",
            extensions: ["swift"],
            filenames: ["Package.swift"]
        ),
        LanguageDescriptor(id: "zig", name: "Zig", extensions: ["zig", "zon"]),
        LanguageDescriptor(id: "sql", name: "SQL", extensions: ["sql"]),
        LanguageDescriptor(id: "yaml", name: "YAML", extensions: ["yml", "yaml"]),
        LanguageDescriptor(
            id: "shell",
            name: "Shell",
            extensions: ["sh", "bash", "zsh"],
            filenames: [".bashrc", ".zshrc", ".profile"],
            shebangs: ["sh", "bash", "zsh"]
        ),
        LanguageDescriptor(
            id: "dockerfile",
            name: "Dockerfile",
            filenames: ["Dockerfile", "dockerfile"]
        ),
    ]
}

public protocol LanguageDetecting: Sendable {
    func detect(url: URL?, firstLine: String?, overrideID: String?) -> LanguageDescriptor
}

public protocol SyntaxHighlighting: Sendable {
    func highlights(for text: String, language: LanguageDescriptor) async throws -> [SyntaxCapture]
}

public struct SyntaxCapture: Equatable, Sendable {
    /// UTF-16 NSRange location/length for TextKit.
    public var utf16Range: Range<Int>
    public var scope: String

    public init(utf16Range: Range<Int>, scope: String) {
        self.utf16Range = utf16Range
        self.scope = scope
    }
}

public enum SyntaxHighlightError: Error, Equatable, Sendable {
    case unsupportedLanguage
    case queryFailed(String)
    case cancelled
}
