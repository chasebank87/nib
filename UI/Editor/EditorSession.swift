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
    @Published public var pendingCaretUTF16: Int?
    @Published public var reducedFeatureMessage: String?
    @Published public var settings: EditorSettings
    @Published public var theme: Theme

    public let commands = CommandRegistry()

    public var onOpen: () -> Void
    public var onSave: () -> Void
    public var onSaveAs: () -> Void
    public var onTextChange: (String) -> Void
    public var onOpenURLs: ([URL]) -> Void

    private var isApplyingFileText = false

    public init(
        text: String = "",
        isPalettePresented: Bool = false,
        isGoToLinePresented: Bool = false,
        settings: EditorSettings = .default,
        theme: Theme = .nibDark,
        onOpen: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onSaveAs: @escaping () -> Void = {},
        onTextChange: @escaping (String) -> Void = { _ in },
        onOpenURLs: @escaping ([URL]) -> Void = { _ in }
    ) {
        self.text = text
        self.isPalettePresented = isPalettePresented
        self.isGoToLinePresented = isGoToLinePresented
        self.settings = settings
        self.theme = theme
        self.onOpen = onOpen
        self.onSave = onSave
        self.onSaveAs = onSaveAs
        self.onTextChange = onTextChange
        self.onOpenURLs = onOpenURLs
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
}
