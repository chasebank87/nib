import AppKit
import NibDomain
import SwiftUI

public struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var caretUTF16: Int
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
        caretUTF16: Binding<Int> = .constant(0),
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
        _caretUTF16 = caretUTF16
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
        Coordinator(text: $text, caretUTF16: $caretUTF16)
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

        // TextKit 1 layout is more reliable for attribute-based syntax colors.
        let textView = NibTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.delegate = context.coordinator
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 8)
        // Rich text must be on for per-token foreground colors; keep it plain otherwise.
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsImageEditing = false
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
        applySyntax(to: textView, force: true, coordinator: context.coordinator)
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

        var textChanged = false
        if textView.string != text {
            let selected = textView.selectedRanges
            context.coordinator.isApplyingExternalText = true
            textView.string = text
            textView.selectedRanges = selected
            context.coordinator.isApplyingExternalText = false
            textChanged = true
        }
        applySyntax(to: textView, force: textChanged, coordinator: context.coordinator)
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
        textView.drawsBackground = true
        textView.insertionPointColor = theme.nsColor(.cursor)
        textView.selectedTextAttributes = [
            .backgroundColor: theme.nsColor(.selection),
            .foregroundColor: foreground,
        ]
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraph,
            .ligature: settings.ligatures ? 1 : 0,
        ]
        textView.defaultParagraphStyle = paragraph
        textView.isHorizontallyResizable = wrapLines == false
        textView.textContainer?.widthTracksTextView = wrapLines
        if wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: max(scrollView.contentSize.width, 1),
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

    private func applySyntax(
        to textView: NibTextView,
        force: Bool,
        coordinator: Coordinator
    ) {
        guard let storage = textView.textStorage else { return }
        let signature = SyntaxPaintSignature(
            textUTF16Length: storage.length,
            themeID: theme.id,
            captureCount: syntaxCaptures.count,
            captureFingerprint: syntaxCaptures.first.map(\.utf16Range.lowerBound) ?? -1,
            lastCaptureEnd: syntaxCaptures.last.map(\.utf16Range.upperBound) ?? -1,
            findCount: findMatches.count,
            highlightingEnabled: capabilities.liveHighlighting
        )
        guard force || coordinator.lastPaintSignature != signature else { return }
        coordinator.lastPaintSignature = signature

        let full = NSRange(location: 0, length: storage.length)
        let foreground = theme.nsColor(.editorForeground)
        let font = Self.font(from: settings)
        let paragraph = (textView.defaultParagraphStyle as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()

        storage.beginEditing()
        if full.length > 0 {
            storage.setAttributes(
                [
                    .foregroundColor: foreground,
                    .font: font,
                    .paragraphStyle: paragraph,
                    .ligature: settings.ligatures ? 1 : 0,
                ],
                range: full
            )
            if capabilities.liveHighlighting {
                for capture in syntaxCaptures {
                    guard let token = theme.token(forSyntaxScope: capture.scope) else { continue }
                    let location = capture.utf16Range.lowerBound
                    let length = capture.utf16Range.count
                    guard location >= 0, length > 0, location + length <= storage.length else { continue }
                    storage.addAttribute(
                        .foregroundColor,
                        value: theme.nsColor(token),
                        range: NSRange(location: location, length: length)
                    )
                }
            }
            for match in findMatches {
                let location = match.lowerBound
                let length = match.count
                guard location >= 0, length > 0, location + length <= storage.length else { continue }
                storage.addAttribute(
                    .backgroundColor,
                    value: theme.nsColor(.searchMatch),
                    range: NSRange(location: location, length: length)
                )
            }
        }
        storage.endEditing()

        // Keep newly typed characters visible in the theme foreground.
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraph,
            .ligature: settings.ligatures ? 1 : 0,
        ]
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
        var caretUTF16: Binding<Int>
        var ruler: LineNumberRulerView?
        var lastPaintSignature: SyntaxPaintSignature?
        var isApplyingExternalText = false

        init(text: Binding<String>, caretUTF16: Binding<Int>) {
            self.text = text
            self.caretUTF16 = caretUTF16
        }

        public func textDidChange(_ notification: Notification) {
            guard isApplyingExternalText == false else { return }
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                // Invalidate paint cache so the next highlight pass can recolor.
                lastPaintSignature = nil
                text.wrappedValue = textView.string
            }
            caretUTF16.wrappedValue = textView.selectedRange().location
            ruler?.needsDisplay = true
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            caretUTF16.wrappedValue = textView.selectedRange().location
        }
    }
}

struct SyntaxPaintSignature: Equatable {
    var textUTF16Length: Int
    var themeID: String
    var captureCount: Int
    var captureFingerprint: Int
    var lastCaptureEnd: Int
    var findCount: Int
    var highlightingEnabled: Bool
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
        // Avoid the default NSRuler accessory/hash chrome that draws a stray separator.
        markers = []
        // Clip so hash/separator chrome cannot bleed under a transparent titlebar.
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        // Do not call super — NSRulerView draws a vertical separator that bleeds
        // into the transparent titlebar under fullSizeContentView.
        theme.nsColor(.gutterBackground).setFill()
        bounds.fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView else { return }

        let foreground = theme.nsColor(.gutterForeground)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        // Empty or untouched buffer still owns line 1.
        if textView.string.isEmpty {
            let label = "1" as NSString
            let size = label.size(withAttributes: [.font: font])
            label.draw(
                at: NSPoint(x: bounds.width - size.width - 6, y: textView.textContainerInset.height),
                withAttributes: [.font: font, .foregroundColor: foreground]
            )
            return
        }

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let relativePoint = self.convert(NSPoint.zero, from: textView)
        let visible = textView.visibleRect
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
        if clamped == 0 { return 1 }
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
