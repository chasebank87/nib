import Foundation

/// Content-Length framed JSON-RPC 2.0 for LSP (NIB-011).
public enum LSPJSONRPC {
    public static func encode(message: Data) -> Data {
        var header = "Content-Length: \(message.count)\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(message)
        return payload
    }

    public static func encodeJSONObject(_ object: [String: Any]) throws -> Data {
        try encode(message: JSONSerialization.data(withJSONObject: object, options: []))
    }

    /// Pulls complete frames from a growing buffer. Returns messages and leftover bytes.
    public static func decode(buffer: inout Data) throws -> [Data] {
        var messages: [Data] = []
        while true {
            guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                break
            }
            let headerData = buffer.subdata(in: 0..<headerRange.lowerBound)
            guard let header = String(data: headerData, encoding: .utf8) else {
                throw LSPClientError.invalidFrame
            }
            guard let lengthLine = header.split(separator: "\r\n").first(where: {
                $0.lowercased().hasPrefix("content-length:")
            }) else {
                throw LSPClientError.invalidFrame
            }
            let lengthString = lengthLine.split(separator: ":").dropFirst().joined(separator: ":")
                .trimmingCharacters(in: .whitespaces)
            guard let length = Int(lengthString), length >= 0 else {
                throw LSPClientError.invalidFrame
            }
            let bodyStart = headerRange.upperBound
            let bodyEnd = bodyStart + length
            guard buffer.count >= bodyEnd else { break }
            messages.append(buffer.subdata(in: bodyStart..<bodyEnd))
            buffer.removeSubrange(0..<bodyEnd)
        }
        return messages
    }
}

public enum LSPClientError: Error, Equatable, Sendable {
    case notStarted
    case invalidFrame
    case serverUnavailable
    case requestFailed(String)
    case cancelled
    case unexpectedResponse
}

public struct LSPPosition: Equatable, Sendable {
    public var line: Int
    public var character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}
