import Foundation
import NibDomain
import NibServices
import Testing

struct LSPJSONRPCTests {
    @Test func framesRoundTripAndPartialBuffers() throws {
        let message = Data(#"{"jsonrpc":"2.0","method":"initialized"}"#.utf8)
        let framed = LSPJSONRPC.encode(message: message)
        var buffer = framed
        let decoded = try LSPJSONRPC.decode(buffer: &buffer)
        #expect(decoded == [message])
        #expect(buffer.isEmpty)

        let partial = framed
        let cut = partial.count / 2
        var firstHalf = partial.subdata(in: 0..<cut)
        let early = try LSPJSONRPC.decode(buffer: &firstHalf)
        #expect(early.isEmpty)
        firstHalf.append(partial.subdata(in: cut..<partial.count))
        let complete = try LSPJSONRPC.decode(buffer: &firstHalf)
        #expect(complete == [message])
    }

    @Test func rejectsMissingContentLength() {
        var buffer = Data("Not-A-Header: 1\r\n\r\n{}".utf8)
        #expect(throws: LSPClientError.invalidFrame) {
            _ = try LSPJSONRPC.decode(buffer: &buffer)
        }
    }
}

struct FakeLSPIntegrationTests {
    @Test func openChangeCloseAndCancelReachFakeServer() async throws {
        let pair = await DemoLanguageServerFactory.make()
        let serverTask = Task { await pair.server.run() }
        defer {
            serverTask.cancel()
        }

        try await pair.client.start()
        let uri = URL(fileURLWithPath: "/tmp/demo.py")
        let identity = LSPDocumentIdentity(uri: uri, languageID: "python", version: 1)
        try await pair.client.openDocument(identity, text: "print()\n")
        try await pair.client.applyChange(
            LSPDocumentIdentity(uri: uri, languageID: "python", version: 2),
            text: "print('hi')\n"
        )

        // Start a completion then cancel outstanding requests.
        let completionTask = Task {
            try await pair.client.completions(
                document: LSPDocumentIdentity(uri: uri, languageID: "python", version: 2),
                position: LSPPosition(line: 0, character: 1)
            )
        }
        await pair.client.cancelAll()
        do {
            _ = try await completionTask.value
        } catch LSPClientError.cancelled {
            // Expected when cancel wins the race.
        } catch {
            // Completion may also finish before cancel; either outcome is fine.
        }

        await pair.client.closeDocument(identity)
        await pair.client.stop()
        await pair.server.stop()

        let opened = await pair.server.openedURIs
        let changed = await pair.server.changedURIs
        let closed = await pair.server.closedURIs
        #expect(opened.contains(uri.absoluteString))
        #expect(changed.contains(uri.absoluteString))
        #expect(closed.contains(uri.absoluteString))
    }

    @Test func completionsHoverAndDiagnosticsMapFromFakeServer() async throws {
        let pair = await DemoLanguageServerFactory.make()
        let serverTask = Task { await pair.server.run() }
        defer {
            serverTask.cancel()
        }

        try await pair.client.start()
        let uri = URL(fileURLWithPath: "/tmp/hover.py")
        let identity = LSPDocumentIdentity(uri: uri, languageID: "python", version: 1)
        let stream = await pair.client.diagnosticsUpdates

        var diagnostics: [Diagnostic] = []
        let diagnosticsTask = Task {
            for await update in stream {
                diagnostics = update
                break
            }
        }

        try await pair.client.openDocument(identity, text: "p")
        _ = await diagnosticsTask.value
        #expect(diagnostics.isEmpty == false)
        #expect(diagnostics.first?.message.contains("Demo diagnostic") == true)

        let completions = try await pair.client.completions(
            document: identity,
            position: LSPPosition(line: 0, character: 1)
        )
        #expect(completions.contains(where: { $0.label == "print" }))

        let hover = try await pair.client.hover(
            document: identity,
            position: LSPPosition(line: 0, character: 0)
        )
        #expect(hover?.contents == "demo hover")

        let locations = try await pair.client.definition(
            document: identity,
            position: LSPPosition(line: 0, character: 0)
        )
        #expect(locations.first?.uri.absoluteString == uri.absoluteString)

        let edits = try await pair.client.formatting(
            document: identity,
            options: .default
        )
        #expect(edits.first?.newText.contains("formatted") == true)

        let renamed = try await pair.client.rename(
            document: identity,
            position: LSPPosition(line: 0, character: 0),
            newName: "hello"
        )
        #expect(renamed.first?.newText == "hello")

        await pair.client.stop()
        await pair.server.stop()
    }
}

struct LSPPositionTests {
    @Test func lspPositionUsesZeroBasedUTF16Offsets() {
        let text = "ab\ncd"
        let position = LineColumnParser.lspPosition(utf16Offset: 4, in: text)
        #expect(position.line == 1)
        #expect(position.character == 1)
    }
}

struct TextEditApplierTests {
    @Test func appliesEditsBottomUp() throws {
        let text = "alpha beta"
        let edits = [
            TextEdit(
                start: LSPPosition(line: 0, character: 6),
                end: LSPPosition(line: 0, character: 10),
                newText: "gamma"
            ),
            TextEdit(
                start: LSPPosition(line: 0, character: 0),
                end: LSPPosition(line: 0, character: 5),
                newText: "ALPHA"
            ),
        ]
        let updated = try TextEditApplier.apply(edits, to: text)
        #expect(updated == "ALPHA gamma")
    }
}

struct ApprovedCommandRunnerTests {
    @Test func runsEcho() throws {
        let result = try ApprovedCommandRunner.run("echo nib-ok", workingDirectory: nil)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("nib-ok"))
    }

    @Test func rejectsEmpty() {
        #expect(throws: ApprovedCommandError.emptyCommand) {
            _ = try ApprovedCommandRunner.run("   ", workingDirectory: nil)
        }
    }
}
