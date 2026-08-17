import AppKit
import NibDomain
import SwiftUI

public struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    var theme: Theme
    var isEditable: Bool

    public init(text: Binding<String>, theme: Theme, isEditable: Bool = true) {
        _text = text
        self.theme = theme
        self.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = text
        applyTheme(to: textView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        applyTheme(to: textView)
        textView.isEditable = isEditable
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
    }

    private func applyTheme(to textView: NSTextView) {
        let background = theme.nsColor(.editorBackground)
        let foreground = theme.nsColor(.editorForeground)
        textView.backgroundColor = background
        textView.insertionPointColor = theme.nsColor(.cursor)
        textView.selectedTextAttributes = [
            .backgroundColor: theme.nsColor(.selection),
            .foregroundColor: foreground,
        ]
        textView.textColor = foreground
        textView.enclosingScrollView?.backgroundColor = background
        textView.enclosingScrollView?.drawsBackground = true
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
        }
    }
}
