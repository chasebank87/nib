import AppKit
import NibDomain
import SwiftUI

public struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var pendingCaretUTF16: Int?
    var theme: Theme
    var settings: EditorSettings
    var isEditable: Bool
    var wrapLines: Bool

    public init(
        text: Binding<String>,
        pendingCaretUTF16: Binding<Int?>,
        theme: Theme,
        settings: EditorSettings,
        isEditable: Bool = true,
        wrapLines: Bool = false
    ) {
        _text = text
        _pendingCaretUTF16 = pendingCaretUTF16
        self.theme = theme
        self.settings = settings
        self.isEditable = isEditable
        self.wrapLines = wrapLines
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        let textView = NibTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.string = text
        scrollView.documentView = textView
        applyChrome(to: textView, scrollView: scrollView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NibTextView else { return }
        context.coordinator.text = $text
        applyChrome(to: textView, scrollView: scrollView)
        textView.isEditable = isEditable
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
        if let offset = pendingCaretUTF16 {
            let clamped = min(max(offset, 0), (textView.string as NSString).length)
            let range = NSRange(location: clamped, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            DispatchQueue.main.async {
                pendingCaretUTF16 = nil
            }
        }
    }

    private func applyChrome(to textView: NibTextView, scrollView: NSScrollView) {
        let background = theme.nsColor(.editorBackground)
        let foreground = theme.nsColor(.editorForeground)
        let font = Self.font(from: settings)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = settings.lineHeight
        paragraph.tabStops = []
        let spaceWidth = NSAttributedString(string: " ", attributes: [.font: font]).size().width
        paragraph.defaultTabInterval = max(spaceWidth, 1) * CGFloat(settings.tabWidth)

        textView.nibInsertSpaces = settings.insertSpaces
        textView.nibTabWidth = settings.tabWidth
        textView.backgroundColor = background
        textView.insertionPointColor = theme.nsColor(.cursor)
        textView.selectedTextAttributes = [
            .backgroundColor: theme.nsColor(.selection),
            .foregroundColor: foreground,
        ]
        textView.textColor = foreground
        textView.font = font
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraph,
            .ligature: settings.ligatures ? 1 : 0,
        ]
        textView.isHorizontallyResizable = wrapLines == false
        textView.textContainer?.widthTracksTextView = wrapLines
        if wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.autoresizingMask = [.width]
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.autoresizingMask = []
        }
        scrollView.hasHorizontalScroller = wrapLines == false
        scrollView.backgroundColor = background
        scrollView.drawsBackground = true
    }

    static func font(from settings: EditorSettings) -> NSFont {
        if settings.fontName == EditorSettings.systemMonospaceName {
            return .monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        }
        return NSFont(name: settings.fontName, size: settings.fontSize)
            ?? .monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
    }

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

final class NibTextView: NSTextView {
    var nibInsertSpaces = true
    var nibTabWidth = 4

    override func insertTab(_ sender: Any?) {
        if nibInsertSpaces {
            let spaces = String(repeating: " ", count: max(nibTabWidth, 1))
            insertText(spaces, replacementRange: selectedRange())
        } else {
            super.insertTab(sender)
        }
    }
}
