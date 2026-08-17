import Foundation

/// How to launch a language server over stdio.
public struct LanguageServerLaunch: Equatable, Sendable {
    public var languageID: String
    public var displayName: String
    public var executable: URL
    public var arguments: [String]

    public init(languageID: String, displayName: String, executable: URL, arguments: [String]) {
        self.languageID = languageID
        self.displayName = displayName
        self.executable = executable
        self.arguments = arguments
    }
}

/// Built-in candidates searched on PATH for auto-detection.
public struct LanguageServerCandidate: Equatable, Sendable {
    public var languageIDs: [String]
    public var displayName: String
    public var executableNames: [String]
    public var arguments: [String]

    public init(
        languageIDs: [String],
        displayName: String,
        executableNames: [String],
        arguments: [String]
    ) {
        self.languageIDs = languageIDs
        self.displayName = displayName
        self.executableNames = executableNames
        self.arguments = arguments
    }
}

public enum LanguageServerCatalog {
    public static let candidates: [LanguageServerCandidate] = [
        LanguageServerCandidate(
            languageIDs: ["python"],
            displayName: "Pyright",
            executableNames: ["pyright-langserver", "basedpyright-langserver"],
            arguments: ["--stdio"]
        ),
        LanguageServerCandidate(
            languageIDs: ["python"],
            displayName: "Pylsp",
            executableNames: ["pylsp"],
            arguments: []
        ),
        LanguageServerCandidate(
            languageIDs: ["typescript", "javascript"],
            displayName: "TypeScript",
            executableNames: ["typescript-language-server"],
            arguments: ["--stdio"]
        ),
        LanguageServerCandidate(
            languageIDs: ["swift"],
            displayName: "SourceKit",
            executableNames: ["sourcekit-lsp"],
            arguments: []
        ),
        LanguageServerCandidate(
            languageIDs: ["zig"],
            displayName: "ZLS",
            executableNames: ["zls"],
            arguments: []
        ),
        LanguageServerCandidate(
            languageIDs: ["go"],
            displayName: "gopls",
            executableNames: ["gopls"],
            arguments: []
        ),
        LanguageServerCandidate(
            languageIDs: ["rust"],
            displayName: "rust-analyzer",
            executableNames: ["rust-analyzer"],
            arguments: []
        ),
        LanguageServerCandidate(
            languageIDs: ["json"],
            displayName: "JSON LS",
            executableNames: ["vscode-json-language-server", "vscode-json-languageserver"],
            arguments: ["--stdio"]
        ),
        LanguageServerCandidate(
            languageIDs: ["yaml"],
            displayName: "YAML LS",
            executableNames: ["yaml-language-server"],
            arguments: ["--stdio"]
        ),
        LanguageServerCandidate(
            languageIDs: ["dockerfile"],
            displayName: "Dockerfile LS",
            executableNames: ["docker-langserver"],
            arguments: ["--stdio"]
        ),
        LanguageServerCandidate(
            languageIDs: ["markdown"],
            displayName: "Marksman",
            executableNames: ["marksman"],
            arguments: ["server"]
        ),
    ]

    public static func candidates(for languageID: String) -> [LanguageServerCandidate] {
        candidates.filter { $0.languageIDs.contains(languageID) }
    }
}
