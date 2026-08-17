import AppKit
import NibDomain
import SwiftUI

public struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var pendingCaretUTF16: Int?
    @Binding var pendingSelectionUTF16: Range<Int>?
    var theme: Theme
    var settings: EditorSettings
    var capabilities: DocumentCapabilities
    var syntaxCaptures: [SyntaxCapture]
    var findMatches: [Range<Int>]
    var isEditable: Bool
    var wrapLines: Bool

    public init(
        text: Binding<String>,
        pendingCaretUTF16: Binding<Int?>,
        pendingSelectionUTF16: Binding<Range<Int>?> = .constant(nil),
        theme: Theme,
        settings: EditorSettings,
        capabilities: DocumentCapabilities = .full,
        syntaxCaptures: [SyntaxCapture] = [],
        findMatches: [Range<Int>] = [],
        isEditable: Bool = true,
        wrapLines: Bool = false
    ) {
        _text = text
        _pendingCaretUTF16 = pendingCaretUTF16
        _pendingSelectionUTF16 = pendingSelectionUTF16
        self.theme = theme
        self.settings = settings
        self.capabilities = capabilities
        self.syntaxCaptures = syntaxCaptures
        self.findMatches = findMatches
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
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = settings.showLineNumbers && capabilities.lineNumbers

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

        let ruler = LineNumberRulerView(textView: textView, theme: theme)
        scrollView.verticalRulerView = ruler
        context.coordinator.ruler = ruler

        applyChrome(to: textView, scrollView: scrollView)
        applySyntax(to: textView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NibTextView else { return }
        context.coordinator.text = $text
        context.coordinator.ruler?.theme = theme
        applyChrome(to: textView, scrollView: scrollView)
        textView.isEditable = isEditable
        let showRuler = settings.showLineNumbers && capabilities.lineNumbers
        scrollView.rulersVisible = showRuler
        scrollView.hasVerticalRuler = showRuler
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
        applySyntax(to: textView)
        context.coordinator.ruler?.needsDisplay = true

        if let offset = pendingCaretUTF16 {
            let clamped = min(max(offset, 0), (textView.string as NSString).length)
            let range = NSRange(location: clamped, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            DispatchQueue.main.async {
                pendingCaretUTF16 = nil
            }
        }
        if let selection = pendingSelectionUTF16 {
            let length = (textView.string as NSString).length
            let location = min(max(selection.lowerBound, 0), length)
            let selLength = min(max(selection.count, 0), length - location)
            let range = NSRange(location: location, length: selLength)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            DispatchQueue.main.async {
                pendingSelectionUTF16 = nil
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

    private func applySyntax(to textView: NibTextView) {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        let foreground = theme.nsColor(.editorForeground)
        let font = Self.font(from: settings)
        storage.beginEditing()
        storage.addAttributes(
            [
                .foregroundColor: foreground,
                .font: font,
                .backgroundColor: NSColor.clear,
            ],
            range: full
        )
        if capabilities.liveHighlighting {
            for capture in syntaxCaptures {
                guard let token = theme.token(forSyntaxScope: capture.scope) else { continue }
                let location = capture.utf16Range.lowerBound
                let length = capture.utf16Range.count
                guard location >= 0, length > 0, location + length <= storage.length else { continue }
                storage.addAttributes(
                    [.foregroundColor: theme.nsColor(token)],
                    range: NSRange(location: location, length: length)
                )
            }
        }
        for match in findMatches {
            let location = match.lowerBound
            let length = match.count
            guard location >= 0, length > 0, location + length <= storage.length else { continue }
            storage.addAttributes(
                [.backgroundColor: theme.nsColor(.searchMatch)],
                range: NSRange(location: location, length: length)
            )
        }
        storage.endEditing()
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
        var ruler: LineNumberRulerView?

        init(text: Binding<String>) {
            self.text = text
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            ruler?.needsDisplay = true
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

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    var theme: Theme

    init(textView: NSTextView, theme: Theme) {
        self.textView = textView
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView else { return }
        theme.nsColor(.gutterBackground).setFill()
        rect.fill()

        let foreground = theme.nsColor(.gutterForeground)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let relativePoint = self.convert(NSPoint.zero, from: textView)
        let visible = textView.visibleRect

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        var index = glyphRange.location
        while index < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: index,
                effectiveRange: &lineRange
            )
            let charIndex = layoutManager.characterIndexForGlyph(at: index)
            let lineNumber = lineNumber(at: charIndex, in: textView.string)
            let y = relativePoint.y + lineRect.minY
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: [.font: font])
            let drawRect = NSRect(
                x: bounds.width - size.width - 6,
                y: y + (lineRect.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            label.draw(
                in: drawRect,
                withAttributes: [
                    .font: font,
                    .foregroundColor: foreground,
                ]
            )
            index = NSMaxRange(lineRange)
        }
    }

    private func lineNumber(at utf16Index: Int, in string: String) -> Int {
        let ns = string as NSString
        let clamped = min(max(utf16Index, 0), ns.length)
        var line = 1
        ns.enumerateSubstrings(
            in: NSRange(location: 0, length: clamped),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            line += 1
        }
        return max(line, 1)
    }
}
