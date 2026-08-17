import AppKit
import NibCoreBridge
import NibDomain
import NibServices

@MainActor
final class AppDelegate: NSObject, @preconcurrency NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = NibDocument.self
        NSDocumentController.shared.maximumRecentDocumentCount = 12
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.core.info("Zig core \(NibCore.version, privacy: .public)")
        AppLog.app.info("nib launched")
        AppComposition.shared.appearance.apply()
        restoreRecoveryIfNeeded()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// Finder / `open -a` delivery. AppKit may import this requirement as
    /// nonisolated; hop before touching NSDocumentController.
    nonisolated func application(_ application: NSApplication, open urls: [URL]) {
        let fileURLs = urls
        Task { @MainActor in
            for url in fileURLs {
                Self.openDocument(at: url)
            }
        }
    }

    private func restoreRecoveryIfNeeded() {
        let payloads = (try? AppComposition.shared.recovery.loadAll()) ?? []
        if payloads.isEmpty {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.newDocument(nil)
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = "Restore unsaved changes?"
        alert.informativeText =
            "nib found \(payloads.count) recovery snapshot(s) from a previous session."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Discard")
        if alert.runModal() == .alertSecondButtonReturn {
            try? AppComposition.shared.recovery.removeAll()
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.newDocument(nil)
            }
            return
        }

        for payload in payloads {
            restore(payload)
        }
        if NSDocumentController.shared.documents.isEmpty {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    private func restore(_ payload: DocumentRecoveryPayload) {
        if let path = payload.filePath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                Self.openDocument(at: url, recovery: payload)
                return
            }
        }
        let document = NibDocument()
        document.applyRecovery(payload)
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
    }

    private static func openDocument(at url: URL, recovery: DocumentRecoveryPayload? = nil) {
        let path = url.path
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            let message = error?.localizedDescription
            Task { @MainActor in
                if let message {
                    AppLog.document.error("open URL failed \(message, privacy: .public)")
                    return
                }
                guard let recovery else { return }
                let document = NSDocumentController.shared.documents
                    .compactMap { $0 as? NibDocument }
                    .first { $0.fileURL?.path == path }
                document?.applyRecovery(recovery)
            }
        }
    }
}
