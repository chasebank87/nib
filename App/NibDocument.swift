import AppKit
import NibDomain
import NibServices
import NibUI
import SwiftUI

@MainActor
@objc(NibDocument)
final class NibDocument: NSDocument {
    let session = EditorSession()

    private let codec = UTF8DocumentCodec()
    private var model = TextDocumentModel()

    override init() {
        super.init()
        hasUndoManager = true
        session.onOpen = { NSDocumentController.shared.openDocument(nil) }
        session.onSave = { [weak self] in self?.save(nil) }
        session.onSaveAs = { [weak self] in self?.saveAs(nil) }
        session.onTextChange = { [weak self] newValue in
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
            session: session,
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
        snapshot.text = session.text
        return try codec.encode(snapshot)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        _ = typeName
        model = try codec.decode(data)
        session.applyFileText(model.text)
        syncWindowChrome()
    }

    override func write(to url: URL, ofType typeName: String) throws {
        try super.write(to: url, ofType: typeName)
        model.text = session.text
        model.markSaved()
        syncWindowChrome()
    }

    private func handleTextEdit(_ newValue: String) {
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
