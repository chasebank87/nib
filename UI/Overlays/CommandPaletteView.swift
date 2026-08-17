import NibDomain
import SwiftUI

public struct CommandPaletteView: View {
    let theme: Theme
    let commands: [EditorCommand]
    let onSelect: (EditorCommand) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedID: String?

    public init(
        theme: Theme,
        commands: [EditorCommand],
        onSelect: @escaping (EditorCommand) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.theme = theme
        self.commands = commands
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    private var filtered: [EditorCommand] {
        CommandFilter.ranked(commands, query: query)
    }

    public var body: some View {
        ZStack {
            theme.color(.editorBackground).opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                TextField("Run a command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.color(.paletteForeground))
                    .padding(14)
                    .onSubmit(runSelected)
                    .accessibilityLabel("Command filter")

                Divider().overlay(theme.color(.overlayBorder))

                if filtered.isEmpty {
                    Text("No matching commands")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.color(.paletteForeground).opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(filtered) { command in
                                paletteRow(command)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(width: 520, height: 320)
            .background(theme.color(.paletteBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Command palette")
        }
        .onAppear {
            selectedID = filtered.first?.id
        }
        .onChange(of: query) { _, _ in
            if filtered.contains(where: { $0.id == selectedID }) == false {
                selectedID = filtered.first?.id
            }
        }
        .onExitCommand(perform: onDismiss)
    }

    private func paletteRow(_ command: EditorCommand) -> some View {
        let selected = command.id == selectedID
        return Button {
            onSelect(command)
        } label: {
            HStack {
                Text(command.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(theme.color(.paletteForeground))
                Spacer()
                if let shortcut = command.shortcutLabel {
                    Text(shortcut)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.color(.paletteForeground).opacity(0.45))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? theme.color(.paletteSelection) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { selectedID = command.id }
        }
    }

    private func runSelected() {
        if let selected = filtered.first(where: { $0.id == selectedID }) ?? filtered.first {
            onSelect(selected)
        }
    }
}
