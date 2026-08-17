import NibDomain
import SwiftUI

/// Simple prompt for rename symbol.
public struct RenameSymbolOverlayView: View {
    @Binding var newName: String
    var theme: Theme
    var onRename: (String) -> Void
    var onDismiss: () -> Void

    public init(
        newName: Binding<String>,
        theme: Theme,
        onRename: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _newName = newName
        self.theme = theme
        self.onRename = onRename
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename Symbol")
                    .font(.headline)
                    .foregroundStyle(theme.color(.overlayForeground))
                TextField("New name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Rename") { onRename(newName) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 360)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }
}
