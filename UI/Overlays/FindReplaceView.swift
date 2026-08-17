import NibDomain
import SwiftUI

public struct FindReplaceView: View {
    @Binding var options: FindOptions
    var status: String?
    var theme: Theme
    var onFind: () -> Void
    var onReplaceAll: () -> Void
    var onDismiss: () -> Void

    @FocusState private var focused: Bool

    public init(
        options: Binding<FindOptions>,
        status: String?,
        theme: Theme,
        onFind: @escaping () -> Void,
        onReplaceAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _options = options
        self.status = status
        self.theme = theme
        self.onFind = onFind
        self.onReplaceAll = onReplaceAll
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Find")
                    .font(.headline)
                    .foregroundStyle(theme.color(.overlayForeground))
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
            }
            TextField("Find", text: $options.query)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(onFind)
            TextField("Replace", text: $options.replacement)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onReplaceAll)
            Toggle("Regular Expression", isOn: $options.useRegularExpression)
            Toggle("Case Sensitive", isOn: $options.caseSensitive)
            Toggle("Whole Word", isOn: $options.wholeWord)
            Toggle("In Selection", isOn: $options.inSelectionOnly)
            HStack {
                Button("Find", action: onFind)
                    .keyboardShortcut(.defaultAction)
                Button("Replace All", action: onReplaceAll)
                if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(theme.color(.overlayBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.color(.overlayBorder), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .onAppear { focused = true }
    }
}
