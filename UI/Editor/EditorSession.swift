import Combine
import Foundation
import NibDomain

public final class EditorSession: ObservableObject {
    @Published public var text: String {
        didSet {
            if isApplyingFileText == false {
                onTextChange(text)
            }
        }
    }

    @Published public var isPalettePresented: Bool
    @Published public var isGoToLinePresented: Bool
    @Published public var isFindPresented: Bool
    @Published public var pendingCaretUTF16: Int?
    @Published public var pendingSelectionUTF16: Range<Int>?
    @Published public var reducedFeatureMessage: String?
    @Published public var settings: EditorSettings
    @Published public var theme: Theme
    @Published public var language: LanguageDescriptor
    @Published public var languageOverrideID: String?
    @Published public var capabilities: DocumentCapabilities
    @Published public var syntaxCaptures: [SyntaxCapture]
    @Published public var findOptions: FindOptions
    @Published public var findMatches: [Range<Int>]
    @Published public var findStatus: String?

    public let commands = CommandRegistry()

    public var onOpen: () -> Void
    public var onSave: () -> Void
    public var onSaveAs: () -> Void
    public var onTextChange: (String) -> Void
    public var onOpenURLs: ([URL]) -> Void
    public var onLanguageOverride: (String?) -> Void
    public var onFindReplaceAll: (FindOptions) -> Void

    private var isApplyingFileText = false

    public init(
        text: String = "",
        isPalettePresented: Bool = false,
        isGoToLinePresented: Bool = false,
        isFindPresented: Bool = false,
        settings: EditorSettings = .default,
        theme: Theme = .nibDark,
        language: LanguageDescriptor = .plainText,
        capabilities: DocumentCapabilities = .full,
        onOpen: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onSaveAs: @escaping () -> Void = {},
        onTextChange: @escaping (String) -> Void = { _ in },
        onOpenURLs: @escaping ([URL]) -> Void = { _ in },
        onLanguageOverride: @escaping (String?) -> Void = { _ in },
        onFindReplaceAll: @escaping (FindOptions) -> Void = { _ in }
    ) {
        self.text = text
        self.isPalettePresented = isPalettePresented
        self.isGoToLinePresented = isGoToLinePresented
        self.isFindPresented = isFindPresented
        self.settings = settings
        self.theme = theme
        self.language = language
        self.capabilities = capabilities
        self.syntaxCaptures = []
        self.findOptions = FindOptions()
        self.findMatches = []
        self.onOpen = onOpen
        self.onSave = onSave
        self.onSaveAs = onSaveAs
        self.onTextChange = onTextChange
        self.onOpenURLs = onOpenURLs
        self.onLanguageOverride = onLanguageOverride
        self.onFindReplaceAll = onFindReplaceAll
    }

    public func applyFileText(_ value: String) {
        isApplyingFileText = true
        text = value
        isApplyingFileText = false
    }

    public func performOpen() {
        onOpen()
    }

    public func performSave() {
        onSave()
    }

    public func performSaveAs() {
        onSaveAs()
    }

    public func goTo(_ target: LineColumn) {
        let clamped = LineColumnParser.clamp(target, in: text)
        pendingCaretUTF16 = LineColumnParser.utf16Offset(of: clamped, in: text)
        isGoToLinePresented = false
    }

    public func runFind() {
        do {
            let ranges = try FindReplaceEngine.findAll(in: text, options: findOptions)
            findMatches = ranges.map { range in
                let ns = NSRange(range, in: text)
                return ns.location..<(ns.location + ns.length)
            }
            findStatus = findMatches.isEmpty ? "No matches" : "\(findMatches.count) matches"
            if let first = findMatches.first {
                pendingSelectionUTF16 = first
            }
        } catch FindError.emptyQuery {
            findMatches = []
            findStatus = nil
        } catch FindError.invalidRegularExpression(let message) {
            findMatches = []
            findStatus = message
        } catch {
            findMatches = []
            findStatus = error.localizedDescription
        }
    }

    public func runReplaceAll() {
        onFindReplaceAll(findOptions)
        runFind()
    }
}
