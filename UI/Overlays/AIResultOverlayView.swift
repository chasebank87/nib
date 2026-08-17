import NibDomain
import SwiftUI

/// Shows an AI reply and optional proposed edit with Apply / Reject.
public struct AIResultOverlayView: View {
    var title: String
    var text: String
    var proposedEdit: String?
    var theme: Theme
    var onApply: (() -> Void)?
    var onDismiss: () -> Void

    public init(
        title: String,
        text: String,
        proposedEdit: String? = nil,
        theme: Theme,
        onApply: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.text = text
        self.proposedEdit = proposedEdit
        self.theme = theme
        self.onApply = onApply
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.color(.overlayForeground))
                    Spacer()
                    Button("Esc", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.color(.overlayForeground))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        if let proposedEdit {
                            Text("Proposed edit")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.color(.overlayForeground).opacity(0.75))
                            Text(proposedEdit)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(theme.color(.overlayForeground))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(theme.color(.gutterBackground).opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .textSelection(.enabled)
                        }
                    }
                }
                HStack {
                    if proposedEdit != nil, let onApply {
                        Button("Reject", action: onDismiss)
                        Spacer()
                        Button("Apply", action: onApply)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Spacer()
                        Button("Done", action: onDismiss)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(16)
            .frame(width: 480, height: proposedEdit == nil ? 280 : 360)
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
