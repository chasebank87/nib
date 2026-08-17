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
    /// Optional LSP 0-based range; resolved to `utf16Range` against buffer text.
    public var lspStart: LSPPosition?
    public var lspEnd: LSPPosition?
    public var utf16Range: Range<Int>?

    public init(
        id: UUID = UUID(),
        message: String,
        severity: DiagnosticSeverity,
        line: Int,
        column: Int,
        lspStart: LSPPosition? = nil,
        lspEnd: LSPPosition? = nil,
        utf16Range: Range<Int>? = nil
    ) {
        self.id = id
        self.message = message
        self.severity = severity
        self.line = line
        self.column = column
        self.lspStart = lspStart
        self.lspEnd = lspEnd
        self.utf16Range = utf16Range
    }

    /// Fills `utf16Range` from LSP positions or line/column against the current buffer.
    public func resolvingUTF16Range(in text: String) -> Diagnostic {
        var copy = self
        if let start = lspStart {
            let lower = LineColumnParser.utf16Offset(
                lspLine: start.line,
                lspCharacter: start.character,
                in: text
            )
            let upper: Int
            if let end = lspEnd {
                upper = max(
                    lower + 1,
                    LineColumnParser.utf16Offset(
                        lspLine: end.line,
                        lspCharacter: end.character,
                        in: text
                    )
                )
            } else {
                upper = Self.defaultEnd(from: lower, in: text)
            }
            let length = (text as NSString).length
            let clampedLower = min(lower, length)
            let clampedUpper = min(max(upper, clampedLower + (length > clampedLower ? 1 : 0)), length)
            if clampedUpper > clampedLower {
                copy.utf16Range = clampedLower..<clampedUpper
            } else {
                copy.utf16Range = nil
            }
            return copy
        }
        if let existing = utf16Range, existing.lowerBound >= 0 {
            let length = (text as NSString).length
            let lower = min(existing.lowerBound, length)
            let upper = min(max(existing.upperBound, lower + 1), length)
            if upper > lower {
                copy.utf16Range = lower..<upper
                return copy
            }
        }
        let lower = LineColumnParser.utf16Offset(
            of: LineColumn(line: line, column: column),
            in: text
        )
        let upper = Self.defaultEnd(from: lower, in: text)
        let length = (text as NSString).length
        let clampedLower = min(lower, length)
        let clampedUpper = min(max(upper, clampedLower + (length > clampedLower ? 1 : 0)), length)
        if clampedUpper > clampedLower {
            copy.utf16Range = clampedLower..<clampedUpper
        } else {
            copy.utf16Range = nil
        }
        return copy
    }

    private static func defaultEnd(from start: Int, in text: String) -> Int {
        let ns = text as NSString
        guard start < ns.length else { return start }
        var end = start + 1
        while end < ns.length, end - start < 24 {
            let character = ns.character(at: end)
            if character == 10 || character == 13 || character == 32 || character == 9 {
                break
            }
            end += 1
        }
        return end
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

public struct LSPLocation: Equatable, Sendable {
    public var uri: URL
    public var start: LSPPosition
    public var end: LSPPosition

    public init(uri: URL, start: LSPPosition, end: LSPPosition) {
        self.uri = uri
        self.start = start
        self.end = end
    }
}

public struct TextEdit: Equatable, Sendable {
    public var start: LSPPosition
    public var end: LSPPosition
    public var newText: String

    public init(start: LSPPosition, end: LSPPosition, newText: String) {
        self.start = start
        self.end = end
        self.newText = newText
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
    func definition(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [LSPLocation]
    func formatting(
        document: LSPDocumentIdentity,
        options: EditorSettings
    ) async throws -> [TextEdit]
    func rename(
        document: LSPDocumentIdentity,
        position: LSPPosition,
        newName: String
    ) async throws -> [TextEdit]
}

public protocol LanguageServerInstalling: Sendable {
    /// First executable found on PATH for this language, if any.
    func installedServer(for languageID: String) -> URL?
    /// Full launch configuration (executable + args) when a server is available.
    func launchConfiguration(for languageID: String) -> LanguageServerLaunch?
}

public protocol DiagnosticPublishing: Sendable {
    var diagnosticsUpdates: AsyncStream<[Diagnostic]> { get }
}
