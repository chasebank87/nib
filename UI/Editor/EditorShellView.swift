import NibDomain
import SwiftUI
import UniformTypeIdentifiers

public struct EditorShellView: View {
    @ObservedObject var session: EditorSession
    let resolveTheme: () -> Theme
    let resolveSettings: () -> EditorSettings

    public init(
        session: EditorSession,
        theme: Theme,
        resolveTheme: @escaping () -> Theme = { Theme.nibDark },
        resolveSettings: @escaping () -> EditorSettings = { .default }
    ) {
        self.session = session
        self.resolveTheme = resolveTheme
        self.resolveSettings = resolveSettings
        session.theme = theme
        session.settings = resolveSettings()
    }

    public var body: some View {
        ZStack {
            session.theme.color(.editorBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(session.language.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(session.theme.color(.gutterForeground))
                    if let message = session.reducedFeatureMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(session.theme.color(.editorForeground).opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(session.theme.color(.gutterBackground))

                EditorTextView(
                    text: $session.text,
                    pendingCaretUTF16: $session.pendingCaretUTF16,
                    pendingSelectionUTF16: $session.pendingSelectionUTF16,
                    theme: session.theme,
                    settings: session.settings,
                    capabilities: session.capabilities,
                    syntaxCaptures: session.syntaxCaptures,
                    findMatches: session.findMatches,
                    wrapLines: session.settings.wrapLines
                        && session.capabilities.wrapLines
                        && session.reducedFeatureMessage == nil
                )
            }
            .padding(.top, 2)

            if session.isPalettePresented {
                CommandPaletteView(
                    theme: session.theme,
                    commands: session.commands.visibleCommands(),
                    onSelect: { command in
                        session.isPalettePresented = false
                        session.commands.perform(command.id)
                    },
                    onDismiss: { session.isPalettePresented = false }
                )
            }

            if session.isGoToLinePresented {
                GoToLineView(
                    theme: session.theme,
                    onGo: { session.goTo($0) },
                    onDismiss: { session.isGoToLinePresented = false }
                )
            }

            if session.isFindPresented {
                FindReplaceView(
                    options: $session.findOptions,
                    status: session.findStatus,
                    theme: session.theme,
                    onFind: { session.runFind() },
                    onReplaceAll: { session.runReplaceAll() },
                    onDismiss: {
                        session.isFindPresented = false
                        session.findMatches = []
                        session.findStatus = nil
                    }
                )
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
        .onReceive(NotificationCenter.default.publisher(for: .nibToggleCommandPalette)) { _ in
            session.isGoToLinePresented = false
            session.isFindPresented = false
            session.isPalettePresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nibGoToLine)) { _ in
            session.isPalettePresented = false
            session.isFindPresented = false
            session.isGoToLinePresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nibFind)) { _ in
            session.isPalettePresented = false
            session.isGoToLinePresented = false
            session.isFindPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nibAppearanceDidChange)) { _ in
            session.theme = resolveTheme()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nibEditorSettingsDidChange)) { _ in
            session.settings = resolveSettings()
            session.theme = resolveTheme()
        }
        .onAppear {
            session.theme = resolveTheme()
            session.settings = resolveSettings()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var claimed = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                claimed = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let itemURL = item as? URL {
                        url = itemURL
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = nil
                    }
                    guard let url else { return }
                    DispatchQueue.main.async {
                        self.session.onOpenURLs([url])
                    }
                }
            }
        }
        return claimed
    }
}
