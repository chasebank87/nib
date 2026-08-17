import NibDomain
import SwiftUI

public struct CompletionOverlayView: View {
    var items: [CompletionItem]
    var theme: Theme
    var onSelect: (CompletionItem) -> Void
    var onDismiss: () -> Void

    public init(
        items: [CompletionItem],
        theme: Theme,
        onSelect: @escaping (CompletionItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.items = items
        self.theme = theme
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Completions")
                    .font(.headline)
                    .foregroundStyle(theme.color(.overlayForeground))
                Spacer()
                Button("Esc", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            if items.isEmpty {
                Text("No completions")
                    .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                    .padding(12)
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Text(item.label)
                                .foregroundStyle(theme.color(.overlayForeground))
                            Spacer()
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(theme.color(.overlayForeground).opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 320)
        .background(theme.color(.overlayBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.color(.overlayBorder), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }
}
