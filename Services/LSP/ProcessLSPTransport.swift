import Foundation
import NibDomain

/// Stdio transport backed by a child `Process` (real language servers).
public actor ProcessLSPTransport: LSPTransporting {
    private let process: Process
    private let stdinHandle: FileHandle
    private let stdoutHandle: FileHandle
    private var closed = false
    private var waiters: [CheckedContinuation<Data?, Error>] = []
    private var inbound = Data()

    public static func launch(executable: URL, arguments: [String]) async throws -> ProcessLSPTransport {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        // Drain stderr so a noisy server cannot fill the pipe and stall.
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let line = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                line.isEmpty == false
            {
                AppLog.lsp.debug("server stderr \(line, privacy: .public)")
            }
        }

        do {
            try process.run()
        } catch {
            throw LSPClientError.serverUnavailable
        }

        let transport = ProcessLSPTransport(
            process: process,
            stdinHandle: stdin.fileHandleForWriting,
            stdoutHandle: stdout.fileHandleForReading
        )
        await transport.startReading()
        return transport
    }

    init(process: Process, stdinHandle: FileHandle, stdoutHandle: FileHandle) {
        self.process = process
        self.stdinHandle = stdinHandle
        self.stdoutHandle = stdoutHandle
    }

    private func startReading() {
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { await self?.receive(data) }
        }
    }

    public func write(_ data: Data) async throws {
        guard closed == false else { throw LSPClientError.serverUnavailable }
        do {
            try stdinHandle.write(contentsOf: data)
        } catch {
            throw LSPClientError.serverUnavailable
        }
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
        guard closed == false else { return }
        closed = true
        stdoutHandle.readabilityHandler = nil
        try? stdinHandle.close()
        try? stdoutHandle.close()
        if process.isRunning {
            process.terminate()
        }
        let pending = waiters
        waiters = []
        for waiter in pending {
            waiter.resume(returning: nil)
        }
    }

    private func receive(_ data: Data) {
        if data.isEmpty {
            closed = true
            stdoutHandle.readabilityHandler = nil
            let pending = waiters
            waiters = []
            for waiter in pending {
                waiter.resume(returning: nil)
            }
            return
        }
        if waiters.isEmpty == false {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: data)
        } else {
            inbound.append(data)
        }
    }
}
