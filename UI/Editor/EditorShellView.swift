import NibDomain
import SwiftUI

public struct EditorShellView: View {
    @ObservedObject var session: EditorSession
    @State private var theme: Theme
    let resolveTheme: () -> Theme
    let onToggleAppearance: () -> Void

    public init(
        session: EditorSession,
        theme: Theme,
        resolveTheme: @escaping () -> Theme = { Theme.nibDark },
        onToggleAppearance: @escaping () -> Void
    ) {
        self.session = session
        _theme = State(initialValue: theme)
        self.resolveTheme = resolveTheme
        self.onToggleAppearance = onToggleAppearance
    }

    private var commands: [EditorCommand] {
        [
            EditorCommand(id: BuiltInCommandID.open, title: "Open…", keywords: ["file"]),
            EditorCommand(id: BuiltInCommandID.save, title: "Save", keywords: ["file"]),
            EditorCommand(id: BuiltInCommandID.saveAs, title: "Save As…", keywords: ["file", "export"]),
            EditorCommand(
                id: BuiltInCommandID.toggleAppearance,
                title: "Toggle Appearance",
                keywords: ["theme", "dark", "light"]
            ),
            EditorCommand(
                id: BuiltInCommandID.togglePalette,
                title: "Close Command Palette",
                keywords: ["dismiss"]
            ),
        ]
    }

    public var body: some View {
        ZStack {
            theme.color(.editorBackground).ignoresSafeArea()
            EditorTextView(text: $session.text, theme: theme)
                .padding(.top, 2)

            if session.isPalettePresented {
                CommandPaletteView(
                    theme: theme,
                    commands: commands,
                    onSelect: perform,
                    onDismiss: { session.isPalettePresented = false }
                )
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .onReceive(NotificationCenter.default.publisher(for: .nibToggleCommandPalette)) { _ in
            session.isPalettePresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nibAppearanceDidChange)) { _ in
            theme = resolveTheme()
        }
    }

    private func perform(_ command: EditorCommand) {
        session.isPalettePresented = false
        switch command.id {
        case BuiltInCommandID.open:
            session.performOpen()
        case BuiltInCommandID.save:
            session.performSave()
        case BuiltInCommandID.saveAs:
            session.performSaveAs()
        case BuiltInCommandID.toggleAppearance:
            onToggleAppearance()
            theme = resolveTheme()
        case BuiltInCommandID.togglePalette:
            break
        default:
            break
        }
    }
}
