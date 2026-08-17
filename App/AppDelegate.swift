import AppKit
import NibCoreBridge
import NibServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = NibDocument.self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.core.info("Zig core \(NibCore.version, privacy: .public)")
        AppLog.app.info("nib launched")
        AppComposition.shared.appearance.apply()
        if NSDocumentController.shared.documents.isEmpty {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Untitled is created once in applicationDidFinishLaunching so SwiftUI
        // Settings-only scenes do not produce a second document.
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
