import AppKit
import NibDomain
import SwiftUI

public struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var caretUTF16: Int
    @Binding var selectionUTF16: Range<Int>
    @Binding var pendingCaretUTF16: Int?
    @Binding var pendingSelectionUTF16: Range<Int>?
    @Binding var diagnosticHover: DiagnosticHover?
    var ghostSuggestion: GhostSuggestion?
    var theme: Theme
    var settings: EditorSettings
    var capabilities: DocumentCapabilities
    var syntaxCaptures: [SyntaxCapture]
    var findMatches: [Range<Int>]
    var diagnostics: [Diagnostic]
    var isEditable: Bool
    var wrapLines: Bool
    var onAcceptGhost: (GhostAcceptMode) -> Void
    var onDismissGhost: () -> Void
    var onCaretMoved: () -> Void

    public init(
        text: Binding<String>,
        caretUTF16: Binding<Int> = .constant(0),
        selectionUTF16: Binding<Range<Int>> = .constant(0..<0),
        pendingCaretUTF16: Binding<Int?>,
        pendingSelectionUTF16: Binding<Range<Int>?> = .constant(nil),
        diagnosticHover: Binding<DiagnosticHover?> = .constant(nil),
        ghostSuggestion: GhostSuggestion? = nil,
        theme: Theme,
        settings: EditorSettings,
        capabilities: DocumentCapabilities = .full,
        syntaxCaptures: [SyntaxCapture] = [],
        findMatches: [Range<Int>] = [],
        diagnostics: [Diagnostic] = [],
        isEditable: Bool = true,
        wrapLines: Bool = false,
        onAcceptGhost: @escaping (GhostAcceptMode) -> Void = { _ in },
        onDismissGhost: @escaping () -> Void = {},
        onCaretMoved: @escaping () -> Void = {}
    ) {
        _text = text
        _caretUTF16 = caretUTF16
        _selectionUTF16 = selectionUTF16
        _pendingCaretUTF16 = pendingCaretUTF16
        _pendingSelectionUTF16 = pendingSelectionUTF16
        _diagnosticHover = diagnosticHover
        self.ghostSuggestion = ghostSuggestion
        self.theme = theme
        self.settings = settings
        self.capabilities = capabilities
        self.syntaxCaptures = syntaxCaptures
        self.findMatches = findMatches
        self.diagnostics = diagnostics
        self.isEditable = isEditable
        self.wrapLines = wrapLines
        self.onAcceptGhost = onAcceptGhost
        self.onDismissGhost = onDismissGhost
        self.onCaretMoved = onCaretMoved
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            caretUTF16: $caretUTF16,
            selectionUTF16: $selectionUTF16,
            diagnosticHover: $diagnosticHover,
            onCaretMoved: onCaretMoved
        )
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
        textView.diagnostics = diagnostics
        textView.ghostSuggestion = ghostSuggestion
        textView.ghostColor = theme.nsColor(.aiSuggestion)
        textView.onAcceptGhost = onAcceptGhost
        textView.onDismissGhost = onDismissGhost
        textView.onDiagnosticHover = { hover in
            context.coordinator.diagnosticHover.wrappedValue = hover
        }

        applyChrome(to: textView, scrollView: scrollView)
        applySyntax(to: textView, force: true, coordinator: context.coordinator)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NibTextView else { return }
        context.coordinator.text = $text
        context.coordinator.caretUTF16 = $caretUTF16
        context.coordinator.selectionUTF16 = $selectionUTF16
        context.coordinator.diagnosticHover = $diagnosticHover
        context.coordinator.onCaretMoved = onCaretMoved
        context.coordinator.ruler?.theme = theme
        textView.diagnostics = diagnostics
        textView.ghostSuggestion = ghostSuggestion
        textView.ghostColor = theme.nsColor(.aiSuggestion)
        textView.onAcceptGhost = onAcceptGhost
        textView.onDismissGhost = onDismissGhost
        textView.onDiagnosticHover = { hover in
            context.coordinator.diagnosticHover.wrappedValue = hover
        }
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
        textView.needsDisplay = true
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
            diagnosticCount: diagnostics.count,
            diagnosticFingerprint: diagnostics.first?.utf16Range?.lowerBound ?? -1,
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
            for diagnostic in diagnostics {
                guard let range = diagnostic.utf16Range else { continue }
                let location = range.lowerBound
                let length = range.count
                guard location >= 0, length > 0, location + length <= storage.length else { continue }
                let color = theme.nsColor(Self.token(for: diagnostic.severity))
                let style = NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue
                storage.addAttribute(
                    .underlineStyle,
                    value: style,
                    range: NSRange(location: location, length: length)
                )
                storage.addAttribute(
                    .underlineColor,
                    value: color,
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

    static func token(for severity: DiagnosticSeverity) -> ThemeToken {
        switch severity {
        case .error: return .diagnosticError
        case .warning: return .diagnosticWarning
        case .information: return .diagnosticInfo
        case .hint: return .diagnosticHint
        }
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
        var selectionUTF16: Binding<Range<Int>>
        var diagnosticHover: Binding<DiagnosticHover?>
        var onCaretMoved: () -> Void
        var ruler: LineNumberRulerView?
        var lastPaintSignature: SyntaxPaintSignature?
        var isApplyingExternalText = false

        init(
            text: Binding<String>,
            caretUTF16: Binding<Int>,
            selectionUTF16: Binding<Range<Int>>,
            diagnosticHover: Binding<DiagnosticHover?>,
            onCaretMoved: @escaping () -> Void
        ) {
            self.text = text
            self.caretUTF16 = caretUTF16
            self.selectionUTF16 = selectionUTF16
            self.diagnosticHover = diagnosticHover
            self.onCaretMoved = onCaretMoved
        }

        public func textDidChange(_ notification: Notification) {
            guard isApplyingExternalText == false else { return }
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                // Invalidate paint cache so the next highlight pass can recolor.
                lastPaintSignature = nil
                text.wrappedValue = textView.string
            }
            let range = textView.selectedRange()
            caretUTF16.wrappedValue = range.location
            selectionUTF16.wrappedValue = range.location..<(range.location + range.length)
            ruler?.needsDisplay = true
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            caretUTF16.wrappedValue = range.location
            selectionUTF16.wrappedValue = range.location..<(range.location + range.length)
            onCaretMoved()
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
    var diagnosticCount: Int
    var diagnosticFingerprint: Int
    var highlightingEnabled: Bool
}

final class NibTextView: NSTextView {
    var nibInsertSpaces = true
    var nibTabWidth = 4
    var diagnostics: [Diagnostic] = []
    var ghostSuggestion: GhostSuggestion?
    var ghostColor: NSColor = .secondaryLabelColor
    var onDiagnosticHover: ((DiagnosticHover?) -> Void)?
    var onAcceptGhost: ((GhostAcceptMode) -> Void)?
    var onDismissGhost: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        if trackingAreas.isEmpty == false {
            trackingAreas.forEach(removeTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGhostSuggestion()
    }

    private func drawGhostSuggestion() {
        guard let ghost = ghostSuggestion,
              ghost.text.isEmpty == false,
              let layoutManager,
              let textContainer
        else { return }
        let length = (string as NSString).length
        let anchor = min(max(ghost.anchorUTF16, 0), length)
        guard selectedRange().location == anchor, selectedRange().length == 0 else { return }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: anchor)
        var fraction: CGFloat = 0
        let rect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 0),
            in: textContainer
        )
        let origin = textContainerOrigin
        let point = NSPoint(x: origin.x + rect.origin.x, y: origin.y + rect.origin.y)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: ghostColor.withAlphaComponent(0.55),
        ]
        (ghost.text as NSString).draw(at: point, withAttributes: attributes)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let layoutManager, let textContainer else {
            onDiagnosticHover?(nil)
            return
        }
        let pointInView = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        let point = NSPoint(x: pointInView.x - origin.x, y: pointInView.y - origin.y)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        if let diagnostic = diagnostics.first(where: { diagnostic in
            guard let range = diagnostic.utf16Range else { return false }
            return range.contains(index)
        }) {
            onDiagnosticHover?(
                DiagnosticHover(
                    diagnosticID: diagnostic.id,
                    message: diagnostic.message,
                    severity: diagnostic.severity,
                    anchorUTF16: index
                )
            )
        } else {
            onDiagnosticHover?(nil)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onDiagnosticHover?(nil)
    }

    override func insertTab(_ sender: Any?) {
        if ghostSuggestion != nil {
            onAcceptGhost?(.all)
            return
        }
        if nibInsertSpaces {
            let spaces = String(repeating: " ", count: max(nibTabWidth, 1))
            insertText(spaces, replacementRange: selectedRange())
        } else {
            super.insertTab(sender)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if ghostSuggestion != nil {
            onDismissGhost?()
            return
        }
        super.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        // Option-Tab → accept first word of ghost text.
        if ghostSuggestion != nil,
           event.charactersIgnoringModifiers == "\t",
           event.modifierFlags.contains(.option)
        {
            onAcceptGhost?(.word)
            return
        }
        super.keyDown(with: event)
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
