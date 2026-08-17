import AppKit
import NibCoreBridge
import NibServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    let composition = AppComposition.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = NibDocument.self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.core.info("Zig core \(NibCore.version, privacy: .public)")
        AppLog.app.info("nib launched")
        composition.appearance.apply()
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
