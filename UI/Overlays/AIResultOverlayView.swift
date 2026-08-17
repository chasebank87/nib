import NibDomain
import SwiftUI

/// Shows an AI reply and optional line diff with Apply / Reject.
public struct AIResultOverlayView: View {
    var title: String
    var text: String
    var proposedEdit: String?
    var originalText: String?
    var theme: Theme
    var onApply: (() -> Void)?
    var onDismiss: () -> Void

    public init(
        title: String,
        text: String,
        proposedEdit: String? = nil,
        originalText: String? = nil,
        theme: Theme,
        onApply: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.text = text
        self.proposedEdit = proposedEdit
        self.originalText = originalText
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
                            Text("Diff review")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.color(.overlayForeground).opacity(0.75))
                            diffBlock(before: originalText ?? "", after: proposedEdit)
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
            .frame(width: 520, height: proposedEdit == nil ? 280 : 400)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    @ViewBuilder
    private func diffBlock(before: String, after: String) -> some View {
        let lines = TextDiff.lines(before: before, after: after)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                Text("\(line.prefix)\(line.text)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(color(for: line.kind))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(background(for: line.kind))
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color(.gutterBackground).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .textSelection(.enabled)
    }

    private func color(for kind: DiffLineKind) -> Color {
        switch kind {
        case .context: return theme.color(.overlayForeground)
        case .insertion: return theme.color(.diagnosticInfo)
        case .deletion: return theme.color(.diagnosticError)
        }
    }

    private func background(for kind: DiffLineKind) -> Color {
        switch kind {
        case .context: return .clear
        case .insertion: return theme.color(.diagnosticInfo).opacity(0.12)
        case .deletion: return theme.color(.diagnosticError).opacity(0.12)
        }
    }
}
