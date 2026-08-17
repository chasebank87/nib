import Foundation
import NibDomain
import os

/// Stdio/pipe JSON-RPC LSP client with document sync, cancellation, and feature requests.
public actor LSPClient: LanguageServerClienting, DiagnosticPublishing {
    private let transport: LSPTransporting
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var buffer = Data()
    private var started = false
    private var readerTask: Task<Void, Never>?
    private var diagnosticsContinuation: AsyncStream<[Diagnostic]>.Continuation?
    public let diagnosticsUpdates: AsyncStream<[Diagnostic]>

    public init(transport: LSPTransporting) {
        self.transport = transport
        var continuation: AsyncStream<[Diagnostic]>.Continuation?
        diagnosticsUpdates = AsyncStream { continuation = $0 }
        diagnosticsContinuation = continuation
    }

    public func start() async throws {
        guard started == false else { return }
        started = true
        readerTask = Task { await self.readLoop() }
        _ = try await request(
            method: "initialize",
            params: [
                "processId": ProcessInfo.processInfo.processIdentifier,
                "clientInfo": ["name": "nib", "version": "0.1.0"],
                "capabilities": [
                    "textDocument": [
                        "synchronization": ["dynamicRegistration": false],
                        "completion": ["dynamicRegistration": false],
                        "hover": ["dynamicRegistration": false],
                        "definition": ["dynamicRegistration": false],
                        "references": ["dynamicRegistration": false],
                        "rename": ["dynamicRegistration": false],
                        "formatting": ["dynamicRegistration": false],
                    ],
                ],
                "rootUri": NSNull(),
            ]
        )
        try await notify(method: "initialized", params: [:])
    }

    public func stop() async {
        if started {
            _ = try? await request(method: "shutdown", params: nil)
            try? await notify(method: "exit", params: nil)
        }
        started = false
        readerTask?.cancel()
        readerTask = nil
        await cancelAll()
        await transport.close()
        diagnosticsContinuation?.finish()
        diagnosticsContinuation = nil
    }

    public func openDocument(_ document: LSPDocumentIdentity, text: String) async throws {
        try await ensureStarted()
        try await notify(
            method: "textDocument/didOpen",
            params: [
                "textDocument": [
                    "uri": document.uri.absoluteString,
                    "languageId": document.languageID,
                    "version": document.version,
                    "text": text,
                ],
            ]
        )
    }

    public func applyChange(_ document: LSPDocumentIdentity, text: String) async throws {
        try await ensureStarted()
        try await notify(
            method: "textDocument/didChange",
            params: [
                "textDocument": [
                    "uri": document.uri.absoluteString,
                    "version": document.version,
                ],
                "contentChanges": [
                    ["text": text],
                ],
            ]
        )
    }

    public func closeDocument(_ document: LSPDocumentIdentity) async {
        try? await notify(
            method: "textDocument/didClose",
            params: [
                "textDocument": [
                    "uri": document.uri.absoluteString,
                ],
            ]
        )
    }

    public func cancelAll() async {
        let ids = Array(pending.keys)
        for id in ids {
            try? await notify(method: "$/cancelRequest", params: ["id": id])
            if let continuation = pending.removeValue(forKey: id) {
                continuation.resume(throwing: LSPClientError.cancelled)
            }
        }
    }

    public func completions(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [CompletionItem] {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/completion",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "position": ["line": position.line, "character": position.character],
            ]
        )
        let items: [[String: Any]]
        if let list = result["items"] as? [[String: Any]] {
            items = list
        } else if result["label"] != nil {
            items = [result]
        } else {
            // Some servers return a bare array as the result root; our request helper
            // wraps objects only. Fall back to empty.
            items = []
        }
        return items.enumerated().compactMap { index, item in
            guard let label = item["label"] as? String else { return nil }
            let insert = (item["insertText"] as? String) ?? label
            return CompletionItem(
                id: "\(label)-\(index)",
                label: label,
                detail: item["detail"] as? String,
                insertText: insert
            )
        }
    }

    public func hover(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> HoverInfo? {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/hover",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "position": ["line": position.line, "character": position.character],
            ]
        )
        if let contents = result["contents"] as? String {
            return HoverInfo(contents: contents)
        }
        if let contents = result["contents"] as? [String: Any],
           let value = contents["value"] as? String
        {
            return HoverInfo(contents: value)
        }
        return nil
    }

    public func definition(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [LSPLocation] {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/definition",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "position": ["line": position.line, "character": position.character],
            ]
        )
        return Self.mapLocations(result)
    }

    public func references(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [LSPLocation] {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/references",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "position": ["line": position.line, "character": position.character],
                "context": ["includeDeclaration": true],
            ]
        )
        return Self.mapLocations(result)
    }

    public func formatting(
        document: LSPDocumentIdentity,
        options: EditorSettings
    ) async throws -> [TextEdit] {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/formatting",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "options": [
                    "tabSize": options.tabWidth,
                    "insertSpaces": options.insertSpaces,
                ],
            ]
        )
        return Self.mapTextEdits(result)
    }

    public func rename(
        document: LSPDocumentIdentity,
        position: LSPPosition,
        newName: String
    ) async throws -> [TextEdit] {
        try await ensureStarted()
        let result = try await request(
            method: "textDocument/rename",
            params: [
                "textDocument": ["uri": document.uri.absoluteString],
                "position": ["line": position.line, "character": position.character],
                "newName": newName,
            ]
        )
        return Self.mapRenameEdits(result, documentURI: document.uri.absoluteString)
    }

    private func ensureStarted() async throws {
        if started == false {
            try await start()
        }
    }

    private func readLoop() async {
        while started {
            do {
                guard let chunk = try await transport.read() else { break }
                buffer.append(chunk)
                let messages = try LSPJSONRPC.decode(buffer: &buffer)
                for message in messages {
                    await handle(message: message)
                }
            } catch {
                AppLog.lsp.error("LSP read failed \(error.localizedDescription, privacy: .public)")
                break
            }
        }
    }

    private func handle(message: Data) async {
        guard
            let object = try? JSONSerialization.jsonObject(with: message) as? [String: Any]
        else { return }

        if let id = object["id"] as? Int, pending[id] != nil {
            let continuation = pending.removeValue(forKey: id)
            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "request failed"
                continuation?.resume(throwing: LSPClientError.requestFailed(message))
            } else if let result = object["result"] {
                if let dict = result as? [String: Any] {
                    continuation?.resume(returning: dict)
                } else if result is NSNull {
                    continuation?.resume(returning: [:])
                } else if let array = result as? [Any] {
                    continuation?.resume(returning: ["items": array])
                } else {
                    continuation?.resume(throwing: LSPClientError.unexpectedResponse)
                }
            } else {
                continuation?.resume(returning: [:])
            }
            return
        }

        if let method = object["method"] as? String,
           method == "textDocument/publishDiagnostics",
           let params = object["params"] as? [String: Any]
        {
            let diagnostics = Self.mapDiagnostics(params)
            diagnosticsContinuation?.yield(diagnostics)
        }
    }

    private static func mapDiagnostics(_ params: [String: Any]) -> [Diagnostic] {
        let raw = params["diagnostics"] as? [[String: Any]] ?? []
        return raw.map { item in
            let severityRaw = item["severity"] as? Int ?? 1
            let severity: DiagnosticSeverity
            switch severityRaw {
            case 1: severity = .error
            case 2: severity = .warning
            case 3: severity = .information
            default: severity = .hint
            }
            let range = item["range"] as? [String: Any]
            let start = range?["start"] as? [String: Any]
            let end = range?["end"] as? [String: Any]
            let startLine = start?["line"] as? Int ?? 0
            let startCharacter = start?["character"] as? Int ?? 0
            let endLine = end?["line"] as? Int ?? startLine
            let endCharacter = end?["character"] as? Int ?? (startCharacter + 1)
            return Diagnostic(
                message: item["message"] as? String ?? "Diagnostic",
                severity: severity,
                line: startLine + 1,
                column: startCharacter + 1,
                lspStart: LSPPosition(line: startLine, character: startCharacter),
                lspEnd: LSPPosition(line: endLine, character: endCharacter)
            )
        }
    }

    private static func mapLocations(_ result: [String: Any]) -> [LSPLocation] {
        if let uri = result["uri"] as? String {
            return [mapLocation(uri: uri, range: result["range"] as? [String: Any])].compactMap { $0 }
        }
        if let targetURI = result["targetUri"] as? String {
            return [
                mapLocation(
                    uri: targetURI,
                    range: (result["targetSelectionRange"] as? [String: Any])
                        ?? (result["targetRange"] as? [String: Any])
                ),
            ].compactMap { $0 }
        }
        let items = result["items"] as? [Any] ?? []
        return items.compactMap { item in
            guard let dict = item as? [String: Any] else { return nil }
            if let uri = dict["uri"] as? String {
                return mapLocation(uri: uri, range: dict["range"] as? [String: Any])
            }
            if let targetURI = dict["targetUri"] as? String {
                return mapLocation(
                    uri: targetURI,
                    range: (dict["targetSelectionRange"] as? [String: Any])
                        ?? (dict["targetRange"] as? [String: Any])
                )
            }
            return nil
        }
    }

    private static func mapLocation(uri: String, range: [String: Any]?) -> LSPLocation? {
        guard let url = URL(string: uri) else { return nil }
        let start = range?["start"] as? [String: Any]
        let end = range?["end"] as? [String: Any]
        return LSPLocation(
            uri: url,
            start: LSPPosition(
                line: start?["line"] as? Int ?? 0,
                character: start?["character"] as? Int ?? 0
            ),
            end: LSPPosition(
                line: end?["line"] as? Int ?? 0,
                character: end?["character"] as? Int ?? 0
            )
        )
    }

    private static func mapTextEdits(_ result: [String: Any]) -> [TextEdit] {
        let items: [[String: Any]]
        if let list = result["items"] as? [[String: Any]] {
            items = list
        } else if result["range"] != nil {
            items = [result]
        } else {
            items = []
        }
        return items.compactMap(mapTextEdit)
    }

    private static func mapRenameEdits(_ result: [String: Any], documentURI: String) -> [TextEdit] {
        if let changes = result["changes"] as? [String: Any],
           let edits = changes[documentURI] as? [[String: Any]]
        {
            return edits.compactMap(mapTextEdit)
        }
        if let documentChanges = result["documentChanges"] as? [[String: Any]] {
            var edits: [TextEdit] = []
            for change in documentChanges {
                let uri = (change["textDocument"] as? [String: Any])?["uri"] as? String
                guard uri == nil || uri == documentURI else { continue }
                let list = change["edits"] as? [[String: Any]] ?? []
                edits.append(contentsOf: list.compactMap(mapTextEdit))
            }
            return edits
        }
        return mapTextEdits(result)
    }

    private static func mapTextEdit(_ item: [String: Any]) -> TextEdit? {
        guard let range = item["range"] as? [String: Any],
              let newText = item["newText"] as? String
        else { return nil }
        let start = range["start"] as? [String: Any]
        let end = range["end"] as? [String: Any]
        return TextEdit(
            start: LSPPosition(
                line: start?["line"] as? Int ?? 0,
                character: start?["character"] as? Int ?? 0
            ),
            end: LSPPosition(
                line: end?["line"] as? Int ?? 0,
                character: end?["character"] as? Int ?? 0
            ),
            newText: newText
        )
    }

    private func request(method: String, params: [String: Any]?) async throws -> [String: Any] {
        let id = nextID
        nextID += 1
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
        ]
        if let params {
            payload["params"] = params
        }
        try await transport.write(LSPJSONRPC.encodeJSONObject(payload))
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
        }
    }

    private func notify(method: String, params: [String: Any]?) async throws {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
        ]
        if let params {
            payload["params"] = params
        }
        try await transport.write(LSPJSONRPC.encodeJSONObject(payload))
    }
}
