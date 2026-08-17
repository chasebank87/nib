import AppKit
import NibDomain
import NibUI
import SwiftUI

@main
struct NibApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EditorSettingsRoot()
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
                Button("Reveal in Finder") {
                    guard let document = NSDocumentController.shared.currentDocument as? NibDocument,
                          let url = document.fileURL
                    else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
            }
            CommandGroup(after: .pasteboard) {
                Button("Find…") {
                    NotificationCenter.default.post(name: .nibFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .nibToggleCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Go to Line…") {
                    NotificationCenter.default.post(name: .nibGoToLine, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
                Button("Toggle Appearance") {
                    AppComposition.shared.appearance.cycle()
                    NotificationCenter.default.post(name: .nibAppearanceDidChange, object: nil)
                }
            }
        }
    }
}

private struct EditorSettingsRoot: View {
    @ObservedObject private var controller = AppComposition.shared.editorSettings

    var body: some View {
        EditorSettingsView(
            settings: $controller.settings,
            themes: AppComposition.shared.themeCatalog.themes
        )
    }
}
