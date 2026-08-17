import Foundation

/// Identifies an open document to a language server. Positions are UTF-16 for LSP compatibility.
public struct LSPDocumentIdentity: Equatable, Sendable {
    public var uri: URL
    public var languageID: String
    public var version: Int

    public init(uri: URL, languageID: String, version: Int) {
        self.uri = uri
        self.languageID = languageID
        self.version = version
    }
}

public struct Diagnostic: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var message: String
    public var severity: DiagnosticSeverity
    public var line: Int
    public var column: Int

    public init(
        id: UUID = UUID(),
        message: String,
        severity: DiagnosticSeverity,
        line: Int,
        column: Int
    ) {
        self.id = id
        self.message = message
        self.severity = severity
        self.line = line
        self.column = column
    }
}

public enum DiagnosticSeverity: String, Equatable, Sendable {
    case error
    case warning
    case information
    case hint
}

public struct CompletionItem: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var detail: String?
    public var insertText: String

    public init(id: String, label: String, detail: String? = nil, insertText: String) {
        self.id = id
        self.label = label
        self.detail = detail
        self.insertText = insertText
    }
}

/// TODO(NIB-011): JSON-RPC stdio client with incremental sync and cancellation.
public protocol LanguageServerClienting: Sendable {
    func openDocument(_ document: LSPDocumentIdentity, text: String) async throws
    func applyChange(_ document: LSPDocumentIdentity, text: String) async throws
    func closeDocument(_ document: LSPDocumentIdentity) async
}

/// TODO(NIB-011): User-visible install and configuration of language servers.
public protocol LanguageServerInstalling: Sendable {
    func installedServer(for languageID: String) -> URL?
}
