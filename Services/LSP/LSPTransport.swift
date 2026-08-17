import Foundation
import NibDomain

/// Bidirectional byte transport for LSP JSON-RPC.
public protocol LSPTransporting: Sendable {
    func write(_ data: Data) async throws
    func read() async throws -> Data?
    func close() async
}

/// In-memory pipe pair for tests and the built-in demo server.
public actor PipeLSPTransport: LSPTransporting {
    private var inbound = Data()
    private var closed = false
    private var waiters: [CheckedContinuation<Data?, Error>] = []
    private weak var peer: PipeLSPTransport?

    public init() {}

    public func connect(to peer: PipeLSPTransport) {
        self.peer = peer
    }

    public func write(_ data: Data) async throws {
        guard let peer else { throw LSPClientError.serverUnavailable }
        await peer.receive(data)
    }

    public func read() async throws -> Data? {
        if inbound.isEmpty == false {
            let chunk = inbound
            inbound = Data()
            return chunk
        }
        if closed { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func close() async {
        closed = true
        let pending = waiters
        waiters = []
        for waiter in pending {
            waiter.resume(returning: nil)
        }
    }

    fileprivate func receive(_ data: Data) {
        if waiters.isEmpty == false {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: data)
        } else {
            inbound.append(data)
        }
    }
}

public enum LSPPipePair {
    public static func make() async -> (client: PipeLSPTransport, server: PipeLSPTransport) {
        let client = PipeLSPTransport()
        let server = PipeLSPTransport()
        await client.connect(to: server)
        await server.connect(to: client)
        return (client, server)
    }
}
