import Foundation
import NibDomain

/// TODO(NIB-011): Replace with a real stdio JSON-RPC client.
public struct UnconfiguredLanguageServer: LanguageServerClienting, LanguageServerInstalling {
    public init() {}

    public func openDocument(_ document: LSPDocumentIdentity, text: String) async throws {
        _ = (document, text)
    }

    public func applyChange(_ document: LSPDocumentIdentity, text: String) async throws {
        _ = (document, text)
    }

    public func closeDocument(_ document: LSPDocumentIdentity) async {
        _ = document
    }

    public func installedServer(for languageID: String) -> URL? {
        _ = languageID
        return nil
    }
}
