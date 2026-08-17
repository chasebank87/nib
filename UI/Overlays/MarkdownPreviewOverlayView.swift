import NibDomain
import SwiftUI

/// Temporary Markdown preview overlay (Phase 6). Dismissible; does not replace the editor.
public struct MarkdownPreviewOverlayView: View {
    var source: String
    var theme: Theme
    var onDismiss: () -> Void

    public init(source: String, theme: Theme, onDismiss: @escaping () -> Void) {
        self.source = source
        self.theme = theme
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Markdown Preview")
                        .font(.headline)
                        .foregroundStyle(theme.color(.overlayForeground))
                    Spacer()
                    Button("Esc", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    Text(attributed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(width: 520, height: 420)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: source)) ?? AttributedString(source)
    }
}
