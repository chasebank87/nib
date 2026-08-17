import AppKit
import NibUI
import SwiftUI

@main
struct NibApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsPlaceholderView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("Open…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Save") {
                    NSDocumentController.shared.currentDocument?.save(nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") {
                    NSDocumentController.shared.currentDocument?.saveAs(nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("View") {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .nibToggleCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Toggle Appearance") {
                    AppComposition.shared.appearance.cycle()
                    NotificationCenter.default.post(name: .nibAppearanceDidChange, object: nil)
                }
            }
        }
    }
}

