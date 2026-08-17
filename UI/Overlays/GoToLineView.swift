import NibDomain
import SwiftUI

public struct GoToLineView: View {
    let theme: Theme
    let onGo: (LineColumn) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var error = ""

    public init(
        theme: Theme,
        onGo: @escaping (LineColumn) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.theme = theme
        self.onGo = onGo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            theme.color(.editorBackground).opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 8) {
                Text("Go to Line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.color(.paletteForeground))
                TextField("12 or 12:4", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.color(.paletteForeground))
                    .onSubmit(go)
                if error.isEmpty == false {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.color(.paletteForeground).opacity(0.65))
                }
            }
            .padding(16)
            .frame(width: 320)
            .background(theme.color(.paletteBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        }
        .onExitCommand(perform: onDismiss)
    }

    private func go() {
        guard let target = LineColumnParser.parse(query) else {
            error = "Use line or line:column"
            return
        }
        onGo(target)
    }
}
