import Combine
import Foundation

public final class EditorSession: ObservableObject {
    @Published public var text: String {
        didSet {
            if isApplyingFileText == false {
                onTextChange(text)
            }
        }
    }

    @Published public var isPalettePresented: Bool

    public var onOpen: () -> Void
    public var onSave: () -> Void
    public var onSaveAs: () -> Void
    public var onTextChange: (String) -> Void

    private var isApplyingFileText = false

    public init(
        text: String = "",
        isPalettePresented: Bool = false,
        onOpen: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onSaveAs: @escaping () -> Void = {},
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.text = text
        self.isPalettePresented = isPalettePresented
        self.onOpen = onOpen
        self.onSave = onSave
        self.onSaveAs = onSaveAs
        self.onTextChange = onTextChange
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
}
