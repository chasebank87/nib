import AppKit
import Combine
import NibDomain
import NibServices
import NibUI
import SwiftUI

@MainActor
@objc(NibDocument)
final class NibDocument: NSDocument, EditorDocumenting {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var model = TextDocumentModel()
    @Published var text = ""
    @Published var isPalettePresented = false

    private let codec = UTF8DocumentCodec()
    private var isApplyingFileContents = false
    private var textObserver: AnyCancellable?

    override init() {
        super.init()
        hasUndoManager = true
        textObserver = $text
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleTextEdit(newValue)
            }
    }

    override class var autosavesInPlace: Bool {
        // TODO(NIB-002): Choose in-place autosave vs recovery copies and document the policy.
        false
    }

    override func makeWindowControllers() {
        let composition = AppComposition.shared
        let root = EditorShellView(
            document: self,
            theme: composition.resolvedTheme(),
            resolveTheme: { composition.resolvedTheme() },
            onToggleAppearance: {
                composition.appearance.cycle()
                NotificationCenter.default.post(name: .nibAppearanceDidChange, object: nil)
            }
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.contentViewController = hosting
        window.minSize = NSSize(width: 480, height: 320)
        window.center()
        window.setFrameAutosaveName("NibEditorWindow")
        addWindowController(NSWindowController(window: window))
        syncWindowChrome()
    }

    override func data(ofType typeName: String) throws -> Data {
        guard typeName.isEmpty == false else {
            throw DocumentError.emptyTypeName
        }
        var snapshot = model
        snapshot.text = text
        return try codec.encode(snapshot)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        _ = typeName
        isApplyingFileContents = true
        defer { isApplyingFileContents = false }
        model = try codec.decode(data)
        text = model.text
        syncWindowChrome()
    }

    override func write(to url: URL, ofType typeName: String) throws {
        try super.write(to: url, ofType: typeName)
        model.text = text
        model.markSaved()
        syncWindowChrome()
    }

    func performOpen() {
        NSDocumentController.shared.openDocument(nil)
    }

    func performSave() {
        save(nil)
    }

    func performSaveAs() {
        saveAs(nil)
    }

    private func handleTextEdit(_ newValue: String) {
        guard isApplyingFileContents == false else { return }
        guard model.text != newValue else { return }
        model.replaceText(newValue)
        updateChangeCount(.changeDone)
        syncWindowChrome()
    }

    private func syncWindowChrome() {
        for controller in windowControllers {
            controller.window?.subtitle = abbreviatedPath
        }
    }

    private var abbreviatedPath: String {
        guard let path = fileURL?.path else { return "" }
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
