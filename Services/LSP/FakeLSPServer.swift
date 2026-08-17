import Foundation
import NibDomain

/// Minimal LSP peer used in tests and as the built-in demo language server.
public actor FakeLSPServer {
    public private(set) var openedURIs: [String] = []
    public private(set) var changedURIs: [String] = []
    public private(set) var closedURIs: [String] = []
    public private(set) var cancelledIDs: [Int] = []
    public var completionItems: [CompletionItem]
    public var hoverText: String
    public var diagnosticMessage: String

    private let transport: LSPTransporting
    private var buffer = Data()
    private var running = false

    public init(
        transport: LSPTransporting,
        completionItems: [CompletionItem] = [
            CompletionItem(id: "print", label: "print", detail: "demo", insertText: "print()"),
        ],
        hoverText: String = "demo hover",
        diagnosticMessage: String = "Demo diagnostic from FakeLSP"
    ) {
        self.transport = transport
        self.completionItems = completionItems
        self.hoverText = hoverText
        self.diagnosticMessage = diagnosticMessage
    }

    public func run() async {
        running = true
        while running {
            do {
                guard let chunk = try await transport.read() else { break }
                buffer.append(chunk)
                let messages = try LSPJSONRPC.decode(buffer: &buffer)
                for message in messages {
                    try await handle(message: message)
                }
            } catch {
                break
            }
        }
    }

    public func stop() async {
        running = false
        await transport.close()
    }

    private func handle(message: Data) async throws {
        guard
            let object = try JSONSerialization.jsonObject(with: message) as? [String: Any]
        else { return }

        if let method = object["method"] as? String {
            let id = object["id"]
            let params = object["params"] as? [String: Any] ?? [:]
            switch method {
            case "initialize":
                try await reply(
                    id: id,
                    result: [
                        "capabilities": [
                            "textDocumentSync": 1,
                            "completionProvider": ["triggerCharacters": ["."]],
                            "hoverProvider": true,
                            "definitionProvider": true,
                            "documentFormattingProvider": true,
                            "renameProvider": true,
                        ],
                        "serverInfo": ["name": "nib-fake-lsp", "version": "0.1.0"],
                    ]
                )
            case "initialized":
                break
            case "shutdown":
                try await reply(id: id, result: NSNull())
            case "exit":
                running = false
            case "textDocument/didOpen":
                if let doc = params["textDocument"] as? [String: Any],
                   let uri = doc["uri"] as? String
                {
                    openedURIs.append(uri)
                    try await publishDiagnostics(uri: uri)
                }
            case "textDocument/didChange":
                if let doc = params["textDocument"] as? [String: Any],
                   let uri = doc["uri"] as? String
                {
                    changedURIs.append(uri)
                    try await publishDiagnostics(uri: uri)
                }
            case "textDocument/didClose":
                if let doc = params["textDocument"] as? [String: Any],
                   let uri = doc["uri"] as? String
                {
                    closedURIs.append(uri)
                }
            case "textDocument/completion":
                let items: [[String: Any]] = completionItems.map { item in
                    var payload: [String: Any] = [
                        "label": item.label,
                        "insertText": item.insertText,
                    ]
                    if let detail = item.detail {
                        payload["detail"] = detail
                    }
                    return payload
                }
                try await reply(id: id, result: ["isIncomplete": false, "items": items])
            case "textDocument/hover":
                try await reply(
                    id: id,
                    result: [
                        "contents": ["kind": "markdown", "value": hoverText],
                    ]
                )
            case "textDocument/definition":
                let uri = ((params["textDocument"] as? [String: Any])?["uri"] as? String)
                    ?? "file:///tmp/demo.py"
                try await reply(
                    id: id,
                    result: [
                        "uri": uri,
                        "range": [
                            "start": ["line": 0, "character": 0],
                            "end": ["line": 0, "character": 5],
                        ],
                    ]
                )
            case "textDocument/formatting":
                try await reply(
                    id: id,
                    result: [
                        [
                            "range": [
                                "start": ["line": 0, "character": 0],
                                "end": ["line": 0, "character": 0],
                            ],
                            "newText": "// formatted\n",
                        ],
                    ]
                )
            case "textDocument/rename":
                let uri = ((params["textDocument"] as? [String: Any])?["uri"] as? String)
                    ?? "file:///tmp/demo.py"
                let newName = params["newName"] as? String ?? "renamed"
                try await reply(
                    id: id,
                    result: [
                        "changes": [
                            uri: [
                                [
                                    "range": [
                                        "start": ["line": 0, "character": 0],
                                        "end": ["line": 0, "character": 5],
                                    ],
                                    "newText": newName,
                                ],
                            ],
                        ],
                    ]
                )
            case "$/cancelRequest":
                if let cancelled = params["id"] as? Int {
                    cancelledIDs.append(cancelled)
                }
            default:
                if id != nil {
                    try await replyError(id: id, message: "Method not found: \(method)")
                }
            }
        }
    }

    private func publishDiagnostics(uri: String) async throws {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "textDocument/publishDiagnostics",
            "params": [
                "uri": uri,
                "diagnostics": [
                    [
                        "range": [
                            "start": ["line": 0, "character": 0],
                            "end": ["line": 0, "character": 1],
                        ],
                        "severity": 2,
                        "message": diagnosticMessage,
                        "source": "nib-fake-lsp",
                    ],
                ],
            ],
        ]
        try await transport.write(LSPJSONRPC.encodeJSONObject(notification))
    }

    private func reply(id: Any?, result: Any) async throws {
        guard let id else { return }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result,
        ]
        try await transport.write(LSPJSONRPC.encodeJSONObject(payload))
    }

    private func replyError(id: Any?, message: String) async throws {
        guard let id else { return }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": -32601, "message": message],
        ]
        try await transport.write(LSPJSONRPC.encodeJSONObject(payload))
    }
}
