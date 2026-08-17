import NibDomain
import SwiftUI

/// Lists LSP locations (Find References). Selecting an in-file hit jumps the caret.
public struct LocationListOverlayView: View {
    var title: String
    var locations: [LSPLocation]
    var theme: Theme
    var onSelect: (LSPLocation) -> Void
    var onDismiss: () -> Void

    public init(
        title: String,
        locations: [LSPLocation],
        theme: Theme,
        onSelect: @escaping (LSPLocation) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.locations = locations
        self.theme = theme
        self.onSelect = onSelect
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
                if locations.isEmpty {
                    Text("No references.")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(locations.enumerated()), id: \.offset) { _, location in
                                Button {
                                    onSelect(location)
                                } label: {
                                    Text(location.displayLabel)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(theme.color(.overlayForeground))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Reference \(location.displayLabel)")
                            }
                        }
                    }
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }
}
