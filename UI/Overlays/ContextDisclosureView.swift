import NibDomain
import SwiftUI

/// Confirms what will be sent to an AI provider before any request runs.
public struct ContextDisclosureView: View {
    var disclosure: ContextDisclosure
    var actionTitle: String
    var theme: Theme
    var onConfirm: () -> Void
    var onCancel: () -> Void

    public init(
        disclosure: ContextDisclosure,
        actionTitle: String,
        theme: Theme,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.disclosure = disclosure
        self.actionTitle = actionTitle
        self.theme = theme
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: 14) {
                Text("Before \(actionTitle)")
                    .font(.headline)
                    .foregroundStyle(theme.color(.overlayForeground))
                Text("Review what will be shared with the provider. Nothing is sent until you continue.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.color(.overlayForeground).opacity(0.8))
                VStack(alignment: .leading, spacing: 6) {
                    row("Selection", "\(disclosure.selectedCharacterCount) characters")
                    row("File path", disclosure.filePath ?? "Untitled (path not included)")
                    row("Diagnostics", disclosure.includesDiagnostics ? "Included" : "Not included")
                    row("Repository context", disclosure.includesRepositoryContext ? "Included" : "Not included")
                    row("Command output", disclosure.includesCommandOutput ? "Included" : "Not included")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.color(.gutterBackground).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Continue", action: onConfirm)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 440)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(theme.color(.overlayForeground))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
