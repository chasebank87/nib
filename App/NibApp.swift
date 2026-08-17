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
                Button("Trigger Completions") {
                    NotificationCenter.default.post(name: .nibComplete, object: nil)
                }
                .keyboardShortcut(" ", modifiers: .control)
                Button("Show Hover") {
                    NotificationCenter.default.post(name: .nibHover, object: nil)
                }
                .keyboardShortcut(".", modifiers: [.command, .option])
                Button("Go to Definition") {
                    NotificationCenter.default.post(name: .nibGoToDefinition, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
                Button("Format Document") {
                    NotificationCenter.default.post(name: .nibFormatDocument, object: nil)
                }
                Button("Rename Symbol") {
                    NotificationCenter.default.post(name: .nibRenameSymbol, object: nil)
                }
                Button("Explain Selection") {
                    NotificationCenter.default.post(name: .nibExplainSelection, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Edit Selection") {
                    NotificationCenter.default.post(name: .nibEditSelection, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Document Selection") {
                    NotificationCenter.default.post(name: .nibDocumentSelection, object: nil)
                }
                Button("Fix Diagnostic") {
                    NotificationCenter.default.post(name: .nibFixDiagnostic, object: nil)
                }
                Button("Ask About This File") {
                    NotificationCenter.default.post(name: .nibAskAboutFile, object: nil)
                }
                Button("Generate from Selection") {
                    NotificationCenter.default.post(name: .nibGenerateSelection, object: nil)
                }
                Button("Inline Suggestion") {
                    NotificationCenter.default.post(name: .nibInlineSuggest, object: nil)
                }
                .keyboardShortcut("]", modifiers: .option)
                Button("Run Agent on Selection") {
                    NotificationCenter.default.post(name: .nibRunAgent, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Markdown Preview") {
                    NotificationCenter.default.post(name: .nibMarkdownPreview, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                Button("Git Status") {
                    NotificationCenter.default.post(name: .nibGitStatus, object: nil)
                }
                Button("Run Approved Command…") {
                    NotificationCenter.default.post(name: .nibRunApprovedCommand, object: nil)
                }
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
            themes: AppComposition.shared.themeCatalog.themes,
            secrets: AppComposition.shared.secrets
        )
    }
}
