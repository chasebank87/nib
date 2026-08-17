import AppKit
import NibDomain
import NibServices
import NibUI
import SwiftUI

@objc(NibDocument)
final class NibDocument: NSDocument {
    private let codec = UTF8DocumentCodec()
    nonisolated(unsafe) private let recoveryID = UUID()
    /// NSDocument callbacks run on the main thread; isolation is not reflected in the AppKit overrides.
    nonisolated(unsafe) private var model = TextDocumentModel()
    nonisolated(unsafe) private var session: EditorSession!
    nonisolated(unsafe) private var recoveryTask: Task<Void, Never>?
    nonisolated(unsafe) private var isWritingToDisk = false
    nonisolated(unsafe) private var lastSeenModificationDate: Date?
    nonisolated(unsafe) private var pendingLargeFileByteCount: Int?
    nonisolated(unsafe) private var highlightTask: Task<Void, Never>?
    nonisolated(unsafe) private var languageOverrideID: String?

    override init() {
        super.init()
        hasUndoManager = true
        MainActor.assumeIsolated {
            let session = EditorSession()
            session.onOpen = { NSDocumentController.shared.openDocument(nil) }
            session.onSave = { [weak self] in self?.save(nil) }
            session.onSaveAs = { [weak self] in self?.saveAs(nil) }
            session.onTextChange = { [weak self] newValue in
                self?.handleTextEdit(newValue)
            }
            session.onOpenURLs = { urls in
                for url in urls {
                    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                        guard let message = error?.localizedDescription else { return }
                        Task { @MainActor in
                            AppLog.document.error(
                                "dropped file failed \(message, privacy: .public)"
                            )
                        }
                    }
                }
            }
            session.onLanguageOverride = { [weak self] overrideID in
                self?.languageOverrideID = overrideID
                self?.refreshLanguageAndHighlight()
            }
            session.onFindReplaceAll = { [weak self] options in
                self?.replaceAll(using: options)
            }
            self.session = session
            self.registerCommands()
        }
    }

    override class var autosavesInPlace: Bool {
        // NIB-002: explicit save only. Recovery snapshots live in Application Support.
        false
    }

    override func makeWindowControllers() {
        MainActor.assumeIsolated {
            let composition = AppComposition.shared
            self.session.theme = composition.resolvedTheme()
            self.session.settings = composition.editorSettings.settings
            let root = EditorShellView(
                session: self.session,
                theme: composition.resolvedTheme(),
                resolveTheme: { composition.resolvedTheme() },
                resolveSettings: { composition.editorSettings.settings }
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
            self.addWindowController(NSWindowController(window: window))
            self.syncWindowChrome()
            self.refreshLanguageAndHighlight()
            if let byteCount = self.pendingLargeFileByteCount {
                self.pendingLargeFileByteCount = nil
                self.presentLargeFileWarning(byteCount: byteCount)
            }
        }
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
        let decoded = try codec.decode(data)
        model = decoded
        session.applyFileText(decoded.text)
        MainActor.assumeIsolated {
            self.session.capabilities = DocumentCapabilities.forByteCount(decoded.byteCount)
            if decoded.isReducedFeature {
                self.session.reducedFeatureMessage =
                    "Large file (\(Self.formatBytes(decoded.byteCount))). Wrapping and live highlighting are off."
            } else {
                self.session.reducedFeatureMessage = nil
            }
            self.syncWindowChrome()
            self.refreshLanguageAndHighlight()
            if DocumentLimits.needsOpenWarning(decoded.byteCount) {
                self.pendingLargeFileByteCount = decoded.byteCount
            }
        }
    }

    override func write(to url: URL, ofType typeName: String) throws {
        isWritingToDisk = true
        defer { isWritingToDisk = false }
        try super.write(to: url, ofType: typeName)
        model.text = session.text
        model.markSaved()
        lastSeenModificationDate = Self.modificationDate(at: url)
        MainActor.assumeIsolated {
            self.clearRecovery()
            self.syncWindowChrome()
        }
    }

    override func close() {
        MainActor.assumeIsolated {
            self.clearRecovery()
        }
        super.close()
    }

    override func presentedItemDidChange() {
        super.presentedItemDidChange()
        let id = recoveryID
        Task { @MainActor in
            Self.registered(id: id)?.handlePresentedItemChange()
        }
    }

    @MainActor
    func applyRecovery(_ payload: DocumentRecoveryPayload) {
        model.text = payload.text
        model.encoding = payload.encoding
        model.lineEnding = payload.lineEnding
        model.isMixedLineEndings = payload.isMixedLineEndings
        model.isDirty = true
        model.originalBytes = nil
        session.applyFileText(payload.text)
        updateChangeCount(.changeDone)
        syncWindowChrome()
        refreshLanguageAndHighlight()
    }

    @MainActor
    private static func registered(id: UUID) -> NibDocument? {
        NSDocumentController.shared.documents
            .compactMap { $0 as? NibDocument }
            .first { $0.recoveryID == id }
    }

    private func handleTextEdit(_ newValue: String) {
        guard model.text != newValue else { return }
        model.replaceText(newValue)
        updateChangeCount(.changeDone)
        MainActor.assumeIsolated {
            self.syncWindowChrome()
            self.scheduleRecoveryWrite()
            self.scheduleHighlight()
        }
    }

    @MainActor
    private func registerCommands() {
        let commands = session.commands
        commands.register(
            EditorCommand(id: BuiltInCommandID.new, title: "New File", keywords: ["untitled"], shortcutLabel: "⌘N")
        ) {
            NSDocumentController.shared.newDocument(nil)
        }
        commands.register(
            EditorCommand(id: BuiltInCommandID.open, title: "Open…", keywords: ["file"], shortcutLabel: "⌘O")
        ) { [weak self] in
            self?.session.performOpen()
        }
        commands.register(
            EditorCommand(id: BuiltInCommandID.save, title: "Save", keywords: ["file"], shortcutLabel: "⌘S")
        ) { [weak self] in
            self?.session.performSave()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.saveAs,
                title: "Save As…",
                keywords: ["file", "export"],
                shortcutLabel: "⇧⌘S"
            )
        ) { [weak self] in
            self?.session.performSaveAs()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.revealInFinder,
                title: "Reveal in Finder",
                keywords: ["folder", "show"],
                shortcutLabel: "⌥⌘R"
            ),
            isEnabled: { [weak self] in self?.fileURL != nil }
        ) { [weak self] in
            self?.revealInFinder()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.goToLine,
                title: "Go to Line…",
                keywords: ["jump", "line", "column"],
                shortcutLabel: "⌘L"
            )
        ) { [weak self] in
            self?.session.isPalettePresented = false
            self?.session.isFindPresented = false
            self?.session.isGoToLinePresented = true
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.find,
                title: "Find…",
                keywords: ["search", "replace", "regex"],
                shortcutLabel: "⌘F"
            )
        ) { [weak self] in
            self?.session.isPalettePresented = false
            self?.session.isGoToLinePresented = false
            self?.session.isFindPresented = true
        }
        for language in LanguageDescriptor.priorityLanguages + [.plainText] {
            let id = "lang.\(language.id)"
            commands.register(
                EditorCommand(
                    id: id,
                    title: "Language: \(language.name)",
                    keywords: ["syntax", language.id]
                )
            ) { [weak self] in
                self?.languageOverrideID = language.id == LanguageDescriptor.plainText.id
                    ? LanguageDescriptor.plainText.id
                    : language.id
                self?.refreshLanguageAndHighlight()
            }
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.toggleAppearance,
                title: "Toggle Appearance",
                keywords: ["theme", "dark", "light"]
            )
        ) {
            AppComposition.shared.appearance.cycle()
            NotificationCenter.default.post(name: .nibAppearanceDidChange, object: nil)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.openSettings,
                title: "Editor Settings…",
                keywords: ["font", "wrap", "tab"],
                shortcutLabel: "⌘,"
            )
        ) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.togglePalette,
                title: "Close Command Palette",
                keywords: ["dismiss"]
            )
        ) { [weak self] in
            self?.session.isPalettePresented = false
        }
    }

    @MainActor
    private func revealInFinder() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    private func scheduleRecoveryWrite() {
        recoveryTask?.cancel()
        let payload = DocumentRecoveryPayload(
            id: recoveryID,
            filePath: fileURL?.path,
            text: session.text,
            encoding: model.encoding,
            lineEnding: model.lineEnding,
            isMixedLineEndings: model.isMixedLineEndings,
            updatedAt: Date()
        )
        recoveryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard Task.isCancelled == false else { return }
            do {
                try AppComposition.shared.recovery.save(payload)
            } catch {
                AppLog.document.error("recovery write failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func clearRecovery() {
        recoveryTask?.cancel()
        recoveryTask = nil
        try? AppComposition.shared.recovery.remove(id: recoveryID)
    }

    @MainActor
    private func handlePresentedItemChange() {
        guard isWritingToDisk == false, let url = fileURL else { return }
        let diskDate = Self.modificationDate(at: url)
        if let diskDate, let lastSeenModificationDate, diskDate <= lastSeenModificationDate {
            return
        }
        switch ExternalChangePolicy.action(isDirty: isDocumentEdited || model.isDirty) {
        case .ignore:
            return
        case .reload:
            reloadFromDiskQuietly()
        case .prompt:
            presentExternalChangeAlert()
        }
    }

    @MainActor
    private func reloadFromDiskQuietly() {
        guard let url = fileURL else { return }
        do {
            let data = try Data(contentsOf: url)
            try read(from: data, ofType: fileType ?? "public.text")
            updateChangeCount(.changeCleared)
            lastSeenModificationDate = Self.modificationDate(at: url)
            AppLog.document.info("reloaded external change \(url.path, privacy: .public)")
        } catch {
            AppLog.document.error("reload failed \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func presentExternalChangeAlert() {
        guard let window = windowForSheet else { return }
        let alert = NSAlert()
        alert.messageText = "This file changed on disk"
        alert.informativeText = "Keep your unsaved edits, or reload the copy from disk?"
        alert.addButton(withTitle: "Keep My Changes")
        alert.addButton(withTitle: "Reload")
        Task { @MainActor [weak self] in
            let response = await alert.beginSheetModal(for: window)
            guard let self else { return }
            if response == .alertSecondButtonReturn {
                self.reloadFromDiskQuietly()
            } else if let url = self.fileURL {
                self.lastSeenModificationDate = Self.modificationDate(at: url)
            }
        }
    }

    @MainActor
    private func presentLargeFileWarning(byteCount: Int) {
        guard let window = windowForSheet else { return }
        let alert = NSAlert()
        alert.messageText = "This file is large"
        alert.informativeText =
            "\(Self.formatBytes(byteCount)). Wrapping and live highlighting are disabled so scrolling stays usable."
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    @MainActor
    private func refreshLanguageAndHighlight() {
        let firstLine = session.text.split(separator: "\n", omittingEmptySubsequences: false).first
            .map(String.init)
        let detected = AppComposition.shared.languageDetector.detect(
            url: fileURL,
            firstLine: firstLine,
            overrideID: languageOverrideID
        )
        session.language = detected
        session.languageOverrideID = languageOverrideID
        scheduleHighlight()
    }

    @MainActor
    private func scheduleHighlight() {
        highlightTask?.cancel()
        guard session.capabilities.liveHighlighting else {
            session.syntaxCaptures = []
            return
        }
        let text = session.text
        let language = session.language
        let highlighter = AppComposition.shared.syntaxHighlighter
        highlightTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard Task.isCancelled == false else { return }
            do {
                let captures = try await highlighter.highlights(for: text, language: language)
                guard Task.isCancelled == false else { return }
                self.session.syntaxCaptures = captures
            } catch is CancellationError {
                return
            } catch {
                self.session.syntaxCaptures = []
            }
        }
    }

    @MainActor
    private func replaceAll(using options: FindOptions) {
        do {
            let result = try FindReplaceEngine.replaceAll(in: session.text, options: options)
            guard result.count > 0 else {
                session.findStatus = "No matches"
                return
            }
            session.applyFileText(result.text)
            handleTextEdit(result.text)
            session.findStatus = "Replaced \(result.count)"
        } catch FindError.invalidRegularExpression(let message) {
            session.findStatus = message
        } catch FindError.emptyQuery {
            session.findStatus = "Enter a query"
        } catch {
            session.findStatus = error.localizedDescription
        }
    }

    @MainActor
    private func syncWindowChrome() {
        for controller in windowControllers {
            controller.window?.representedURL = fileURL
            controller.window?.subtitle = abbreviatedPath
        }
    }

    @MainActor
    private var abbreviatedPath: String {
        guard let path = fileURL?.path else { return "" }
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // NSDocument I/O overrides are nonisolated; keep these helpers callable there.
    nonisolated private static func modificationDate(at url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    nonisolated private static func formatBytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}
