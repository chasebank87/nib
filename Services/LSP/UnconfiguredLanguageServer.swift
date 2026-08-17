import Foundation
import NibDomain

/// No-op client used when LSP is disabled or no server is configured.
public struct UnconfiguredLanguageServer: LanguageServerClienting, LanguageServerInstalling {
    public init() {}

    public func start() async throws {}
    public func stop() async {}

    public func openDocument(_ document: LSPDocumentIdentity, text: String) async throws {
        _ = (document, text)
    }

    public func applyChange(_ document: LSPDocumentIdentity, text: String) async throws {
        _ = (document, text)
    }

    public func closeDocument(_ document: LSPDocumentIdentity) async {
        _ = document
    }

    public func cancelAll() async {}

    public func completions(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [CompletionItem] {
        _ = (document, position)
        return []
    }

    public func hover(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> HoverInfo? {
        _ = (document, position)
        return nil
    }

    public func definition(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [LSPLocation] {
        _ = (document, position)
        return []
    }

    public func references(
        document: LSPDocumentIdentity,
        position: LSPPosition
    ) async throws -> [LSPLocation] {
        _ = (document, position)
        return []
    }

    public func formatting(
        document: LSPDocumentIdentity,
        options: EditorSettings
    ) async throws -> [TextEdit] {
        _ = (document, options)
        return []
    }

    public func rename(
        document: LSPDocumentIdentity,
        position: LSPPosition,
        newName: String
    ) async throws -> [TextEdit] {
        _ = (document, position, newName)
        return []
    }

    public func installedServer(for languageID: String) -> URL? {
        _ = languageID
        return nil
    }

    public func launchConfiguration(for languageID: String) -> LanguageServerLaunch? {
        _ = languageID
        return nil
    }
}

/// Boots the built-in FakeLSP over an in-process pipe pair for demo / tests.
public enum DemoLanguageServerFactory {
    public static func make() async -> (client: LSPClient, server: FakeLSPServer) {
        let pair = await LSPPipePair.make()
        let server = FakeLSPServer(transport: pair.server)
        let client = LSPClient(transport: pair.client)
        return (client, server)
    }
}
