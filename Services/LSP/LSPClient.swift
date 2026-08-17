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
        } else if let bare = result as? [String: Any], bare["label"] != nil {
            items = [bare]
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
            return Diagnostic(
                message: item["message"] as? String ?? "Diagnostic",
                severity: severity,
                line: (start?["line"] as? Int ?? 0) + 1,
                column: (start?["character"] as? Int ?? 0) + 1
            )
        }
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
