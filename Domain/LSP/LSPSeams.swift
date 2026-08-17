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
    public var utf16Range: Range<Int>?

    public init(
        id: UUID = UUID(),
        message: String,
        severity: DiagnosticSeverity,
        line: Int,
        column: Int,
        utf16Range: Range<Int>? = nil
    ) {
        self.id = id
        self.message = message
        self.severity = severity
        self.line = line
        self.column = column
        self.utf16Range = utf16Range
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

public struct HoverInfo: Equatable, Sendable {
    public var contents: String

    public init(contents: String) {
        self.contents = contents
    }
}

/// JSON-RPC stdio (or pipe) language server client with incremental sync.
public protocol LanguageServerClienting: Sendable {
    func start() async throws
    func stop() async
    func openDocument(_ document: LSPDocumentIdentity, text: String) async throws
    func applyChange(_ document: LSPDocumentIdentity, text: String) async throws
    func closeDocument(_ document: LSPDocumentIdentity) async
    func cancelAll() async
    func completions(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [CompletionItem]
    func hover(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> HoverInfo?
}

public protocol LanguageServerInstalling: Sendable {
    func installedServer(for languageID: String) -> URL?
}

public protocol DiagnosticPublishing: Sendable {
    var diagnosticsUpdates: AsyncStream<[Diagnostic]> { get }
}
