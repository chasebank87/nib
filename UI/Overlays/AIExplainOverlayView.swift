import NibDomain
import SwiftUI

public struct AIExplainOverlayView: View {
    var text: String
    var theme: Theme
    var onDismiss: () -> Void

    public init(text: String, theme: Theme, onDismiss: @escaping () -> Void) {
        self.text = text
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
                    Text("Explain Selection")
                        .font(.headline)
                        .foregroundStyle(theme.color(.overlayForeground))
                    Spacer()
                    Button("Esc", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.color(.overlayForeground))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(width: 440, height: 280)
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
