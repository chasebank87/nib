import AppKit
import Combine
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
    nonisolated(unsafe) private var languageDetectTask: Task<Void, Never>?
    nonisolated(unsafe) private var languageOverrideID: String?
    nonisolated(unsafe) private var lspVersion = 0
    nonisolated(unsafe) private var lspIsOpen = false
    nonisolated(unsafe) private var lspSyncTask: Task<Void, Never>?
    nonisolated(unsafe) private var lspFeatureTask: Task<Void, Never>?
    nonisolated(unsafe) private var ghostTask: Task<Void, Never>?
    nonisolated(unsafe) private var sharingPicker: NSSharingServicePicker?
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()

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
            session.onRequestCompletions = { [weak self] in
                self?.requestCompletions()
            }
            session.onInsertCompletion = { [weak self] item in
                self?.insertCompletion(item)
            }
            session.onRequestHover = { [weak self] in
                self?.requestHover()
            }
            session.onAIAction = { [weak self] kind in
                self?.beginAIAction(kind)
            }
            session.onConfirmAIDisclosure = { [weak self] in
                self?.confirmAIDisclosure()
            }
            session.onApplyAIEdit = { [weak self] in
                self?.applyAIEdit()
            }
            session.onRequestInlineSuggestion = { [weak self] in
                self?.requestInlineSuggestion()
            }
            session.onAcceptGhost = { [weak self] mode in
                self?.acceptGhost(mode)
            }
            session.onDismissGhost = { [weak self] in
                self?.session.ghostSuggestion = nil
            }
            session.onRunAgentPlan = { [weak self] in
                self?.beginAgentPlan()
            }
            session.onConfirmAgentPlan = { [weak self] in
                self?.confirmAgentPlan()
            }
            session.onApplyAgentEdit = { [weak self] in
                self?.applyAgentEdit()
            }
            session.onInspectGit = { [weak self] in
                self?.showGitStatus()
            }
            session.onGoToDefinition = { [weak self] in
                self?.goToDefinition()
            }
            session.onFindReferences = { [weak self] in
                self?.findReferences()
            }
            session.onFormatDocument = { [weak self] in
                self?.formatDocument()
            }
            session.onBeginRename = { [weak self] in
                self?.beginRename()
            }
            session.onConfirmRename = { [weak self] name in
                self?.confirmRename(name)
            }
            session.onBeginApprovedCommand = { [weak self] in
                self?.beginApprovedCommand()
            }
            session.onConfirmApprovedCommand = { [weak self] command in
                self?.confirmApprovedCommand(command)
            }
            session.onOpenReference = { [weak self] location in
                self?.openReference(location)
            }
            session.onShareFile = { [weak self] in
                self?.shareFile()
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
            window.titlebarSeparatorStyle = .none
            window.contentViewController = hosting
            window.minSize = NSSize(width: 480, height: 320)
            window.center()
            window.setFrameAutosaveName("NibEditorWindow")
            self.addWindowController(NSWindowController(window: window))
            self.syncWindowChrome()
            self.bindLanguageServer()
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
            self.refreshGitFileStatus()
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
            self.refreshGitFileStatus()
        }
    }

    override func save(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let shouldFormat = MainActor.assumeIsolated {
            session.settings.formatOnSave && session.capabilities.languageServers
        }
        guard shouldFormat else {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
            return
        }
        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler(nil)
                return
            }
            await self.formatBeforeSaveIfEnabled()
            self.finishSave(
                to: url,
                ofType: typeName,
                for: saveOperation,
                completionHandler: completionHandler
            )
        }
    }

    private func finishSave(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }

    override func close() {
        MainActor.assumeIsolated {
            self.clearRecovery()
            self.closeLanguageServerDocument()
            self.cancellables.removeAll()
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
            self.scheduleLanguageAutoDetect()
            self.scheduleInlineSuggestion()
            // Keep underline ranges aligned with the live buffer.
            if self.session.diagnostics.isEmpty == false {
                self.session.applyDiagnostics(self.session.diagnostics)
            }
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
            self?.session.dismissTransientOverlays()
            self?.session.isFindPresented = true
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.complete,
                title: "Trigger Completions",
                keywords: ["lsp", "suggest", "autocomplete"],
                shortcutLabel: "⌃Space"
            )
        ) { [weak self] in
            self?.requestCompletions()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.hover,
                title: "Show Hover",
                keywords: ["lsp", "docs", "info"],
                shortcutLabel: "⌥⌘."
            )
        ) { [weak self] in
            self?.requestHover()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.goToDefinition,
                title: "Go to Definition",
                keywords: ["lsp", "jump", "definition"],
                shortcutLabel: "⌘]"
            )
        ) { [weak self] in
            self?.goToDefinition()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.findReferences,
                title: "Find References",
                keywords: ["lsp", "references", "usages"],
                shortcutLabel: "⇧⌘]"
            )
        ) { [weak self] in
            self?.findReferences()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.formatDocument,
                title: "Format Document",
                keywords: ["lsp", "format", "prettier"]
            )
        ) { [weak self] in
            self?.formatDocument()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.renameSymbol,
                title: "Rename Symbol",
                keywords: ["lsp", "rename", "refactor"]
            )
        ) { [weak self] in
            self?.beginRename()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.explainSelection,
                title: "Explain Selection",
                keywords: ["ai", "mock", "explain"],
                shortcutLabel: "⇧⌘E"
            )
        ) { [weak self] in
            self?.beginAIAction(.explain)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.editSelection,
                title: "Edit Selection",
                keywords: ["ai", "mock", "refactor", "edit"],
                shortcutLabel: "⇧⌘R"
            )
        ) { [weak self] in
            self?.beginAIAction(.edit)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.documentSelection,
                title: "Document Selection",
                keywords: ["ai", "mock", "docstring", "comment"]
            )
        ) { [weak self] in
            self?.beginAIAction(.document)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.fixDiagnostic,
                title: "Fix Diagnostic",
                keywords: ["ai", "fix", "diagnostic", "error"]
            )
        ) { [weak self] in
            self?.beginAIAction(.fixDiagnostic)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.askAboutFile,
                title: "Ask About This File",
                keywords: ["ai", "file", "ask", "overview"]
            )
        ) { [weak self] in
            self?.beginAIAction(.askAboutFile)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.generateSelection,
                title: "Generate from Selection",
                keywords: ["ai", "generate", "continue"]
            )
        ) { [weak self] in
            self?.beginAIAction(.generate)
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.inlineSuggest,
                title: "Inline Suggestion",
                keywords: ["ai", "ghost", "complete", "inline"],
                shortcutLabel: "⌥]"
            )
        ) { [weak self] in
            self?.requestInlineSuggestion()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.runAgent,
                title: "Run Agent on Selection",
                keywords: ["ai", "agent", "plan", "tools"],
                shortcutLabel: "⇧⌘A"
            )
        ) { [weak self] in
            self?.beginAgentPlan()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.markdownPreview,
                title: "Markdown Preview",
                keywords: ["preview", "markdown", "md"],
                shortcutLabel: "⌥⌘M"
            )
        ) { [weak self] in
            self?.session.dismissTransientOverlays()
            self?.session.isMarkdownPreviewPresented = true
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.gitStatus,
                title: "Git Status",
                keywords: ["git", "diff", "status"]
            )
        ) { [weak self] in
            self?.showGitStatus()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.shareFile,
                title: "Share…",
                keywords: ["share", "export"]
            )
        ) { [weak self] in
            self?.shareFile()
        }
        commands.register(
            EditorCommand(
                id: BuiltInCommandID.runApprovedCommand,
                title: "Run Approved Command…",
                keywords: ["shell", "terminal", "command", "run"]
            )
        ) { [weak self] in
            self?.beginApprovedCommand()
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
            content: session.text,
            overrideID: languageOverrideID
        )
        let languageChanged = detected.id != session.language.id
        session.language = detected
        session.languageOverrideID = languageOverrideID
        scheduleHighlight()
        if languageChanged || lspIsOpen == false {
            scheduleLanguageServerSync(forceReopen: true)
        } else {
            scheduleLanguageServerChange()
        }
    }

    /// When the user has not pinned a language, re-detect from path/shebang/content while typing.
    @MainActor
    private func scheduleLanguageAutoDetect() {
        guard languageOverrideID == nil else {
            scheduleHighlight()
            scheduleLanguageServerChange()
            return
        }
        languageDetectTask?.cancel()
        languageDetectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard Task.isCancelled == false, let self else { return }
            self.refreshLanguageAndHighlight()
        }
    }

    @MainActor
    private func scheduleLanguageServerSync(forceReopen: Bool) {
        lspSyncTask?.cancel()
        lspSyncTask = Task { @MainActor [weak self] in
            if forceReopen == false {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            guard Task.isCancelled == false else { return }
            await self?.syncLanguageServerDocument(forceReopen: forceReopen)
        }
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

    @MainActor
    private func bindLanguageServer() {
        cancellables.removeAll()
        let servers = AppComposition.shared.languageServers
        session.lspStatus = servers.statusMessage
        session.applyDiagnostics(servers.diagnostics)
        servers.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.session.lspStatus = status
            }
            .store(in: &cancellables)
        servers.$diagnostics
            .receive(on: RunLoop.main)
            .sink { [weak self] diagnostics in
                self?.session.applyDiagnostics(diagnostics)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .nibEditorSettingsDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncLanguageServerDocument(forceReopen: true)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func lspDocumentIdentity() -> LSPDocumentIdentity {
        let uri = fileURL
            ?? URL(string: "untitled://\(recoveryID.uuidString)")!
        return LSPDocumentIdentity(
            uri: uri,
            languageID: session.language.id,
            version: lspVersion
        )
    }

    @MainActor
    private func syncLanguageServerDocument(forceReopen: Bool) async {
        guard session.capabilities.languageServers else {
            await closeLanguageServerDocumentAsync()
            session.applyDiagnostics([])
            return
        }
        let servers = AppComposition.shared.languageServers
        let languageID = session.language.id

        if forceReopen {
            await closeLanguageServerDocumentAsync()
            await servers.activate(for: languageID)
            lspVersion = max(lspVersion + 1, 1)
            let identity = lspDocumentIdentity()
            do {
                try await servers.client.openDocument(identity, text: session.text)
                lspIsOpen = true
            } catch {
                AppLog.lsp.error("document open failed \(error.localizedDescription, privacy: .public)")
            }
            return
        }

        await servers.activate(for: languageID)
        lspVersion = max(lspVersion + 1, 1)
        let identity = lspDocumentIdentity()
        do {
            if lspIsOpen {
                try await servers.client.applyChange(identity, text: session.text)
            } else {
                try await servers.client.openDocument(identity, text: session.text)
                lspIsOpen = true
            }
        } catch {
            AppLog.lsp.error("document sync failed \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func scheduleLanguageServerChange() {
        guard session.capabilities.languageServers else { return }
        scheduleLanguageServerSync(forceReopen: false)
    }

    @MainActor
    private func closeLanguageServerDocument() {
        lspSyncTask?.cancel()
        lspFeatureTask?.cancel()
        Task { @MainActor [weak self] in
            await self?.closeLanguageServerDocumentAsync()
        }
    }

    @MainActor
    private func closeLanguageServerDocumentAsync() async {
        guard lspIsOpen else { return }
        let identity = lspDocumentIdentity()
        lspIsOpen = false
        await AppComposition.shared.languageServer.closeDocument(identity)
    }

    @MainActor
    private func requestCompletions() {
        guard session.capabilities.languageServers else {
            session.completions = []
            session.isCompletionPresented = true
            return
        }
        session.dismissTransientOverlays()
        let caret = session.caretUTF16
        let text = session.text
        let position = LineColumnParser.lspPosition(utf16Offset: caret, in: text)
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let items = try await AppComposition.shared.languageServer.completions(
                    document: self.lspDocumentIdentity(),
                    position: position
                )
                guard Task.isCancelled == false else { return }
                self.session.completions = items
                self.session.isCompletionPresented = true
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.completions = []
                self.session.isCompletionPresented = true
                AppLog.lsp.error("completion failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func insertCompletion(_ item: CompletionItem) {
        let caret = min(max(session.caretUTF16, 0), (session.text as NSString).length)
        let ns = session.text as NSString
        let inserted = item.insertText as NSString
        let newText = ns.substring(to: caret) + item.insertText + ns.substring(from: caret)
        session.applyFileText(newText)
        handleTextEdit(newText)
        session.pendingCaretUTF16 = caret + inserted.length
        session.caretUTF16 = caret + inserted.length
        session.isCompletionPresented = false
        session.completions = []
    }

    @MainActor
    private func requestHover() {
        guard session.capabilities.languageServers else {
            session.hoverText = nil
            return
        }
        let caret = session.caretUTF16
        let text = session.text
        let position = LineColumnParser.lspPosition(utf16Offset: caret, in: text)
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let hover = try await AppComposition.shared.languageServer.hover(
                    document: self.lspDocumentIdentity(),
                    position: position
                )
                guard Task.isCancelled == false else { return }
                self.session.hoverText = hover?.contents
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.hoverText = nil
                AppLog.lsp.error("hover failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func goToDefinition() {
        guard session.capabilities.languageServers else {
            session.hoverText = "Language server is off."
            return
        }
        let caret = session.caretUTF16
        let position = LineColumnParser.lspPosition(utf16Offset: caret, in: session.text)
        let currentURI = lspDocumentIdentity().uri
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let locations = try await AppComposition.shared.languageServer.definition(
                    document: self.lspDocumentIdentity(),
                    position: position
                )
                guard Task.isCancelled == false else { return }
                guard let first = locations.first else {
                    self.session.hoverText = "No definition found."
                    return
                }
                if first.uri == currentURI || first.uri.absoluteString == currentURI.absoluteString {
                    let offset = LineColumnParser.utf16Offset(
                        lspLine: first.start.line,
                        lspCharacter: first.start.character,
                        in: self.session.text
                    )
                    self.session.pendingCaretUTF16 = offset
                    self.session.hoverText = nil
                } else {
                    self.session.hoverText =
                        "Definition is in another file:\n\(first.uri.path)\nL\(first.start.line + 1):\(first.start.character + 1)"
                }
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.hoverText = error.localizedDescription
                AppLog.lsp.error("definition failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func findReferences() {
        guard session.capabilities.languageServers else {
            session.hoverText = "Language server is off."
            return
        }
        let caret = session.caretUTF16
        let position = LineColumnParser.lspPosition(utf16Offset: caret, in: session.text)
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let locations = try await AppComposition.shared.languageServer.references(
                    document: self.lspDocumentIdentity(),
                    position: position
                )
                guard Task.isCancelled == false else { return }
                self.session.dismissTransientOverlays()
                self.session.referenceLocations = locations
                self.session.isReferencesPresented = true
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.hoverText = error.localizedDescription
                AppLog.lsp.error("references failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func openReference(_ location: LSPLocation) {
        session.isReferencesPresented = false
        let currentURI = lspDocumentIdentity().uri
        if location.uri == currentURI || location.uri.absoluteString == currentURI.absoluteString {
            let offset = LineColumnParser.utf16Offset(
                lspLine: location.start.line,
                lspCharacter: location.start.character,
                in: session.text
            )
            session.pendingCaretUTF16 = offset
            return
        }
        session.hoverText =
            "Reference is in another file:\n\(location.uri.path)\nL\(location.start.line + 1):\(location.start.character + 1)"
    }

    @MainActor
    private func formatDocument() {
        guard session.capabilities.languageServers else {
            session.hoverText = "Language server is off."
            return
        }
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let edits = try await AppComposition.shared.languageServer.formatting(
                    document: self.lspDocumentIdentity(),
                    options: self.session.settings
                )
                guard Task.isCancelled == false else { return }
                guard edits.isEmpty == false else {
                    self.session.hoverText = "Formatter returned no edits."
                    return
                }
                let updated = try TextEditApplier.apply(edits, to: self.session.text)
                self.session.applyFileText(updated)
                self.handleTextEdit(updated)
                self.session.hoverText = "Formatted (\(edits.count) edits)."
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.hoverText = error.localizedDescription
                AppLog.lsp.error("format failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func formatBeforeSaveIfEnabled() async {
        guard session.settings.formatOnSave,
              session.capabilities.languageServers
        else { return }
        do {
            await syncLanguageServerDocument(forceReopen: false)
            let edits = try await AppComposition.shared.languageServer.formatting(
                document: lspDocumentIdentity(),
                options: session.settings
            )
            guard edits.isEmpty == false else { return }
            let updated = try TextEditApplier.apply(edits, to: session.text)
            session.applyFileText(updated)
            handleTextEdit(updated)
        } catch {
            AppLog.lsp.error("format on save failed \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func beginRename() {
        session.dismissTransientOverlays()
        let word = wordNearCaret()
        session.renameDraft = word
        session.isRenamePresented = true
    }

    @MainActor
    private func confirmRename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        session.isRenamePresented = false
        guard trimmed.isEmpty == false else { return }
        guard session.capabilities.languageServers else {
            session.hoverText = "Language server is off."
            return
        }
        let caret = session.caretUTF16
        let position = LineColumnParser.lspPosition(utf16Offset: caret, in: session.text)
        lspFeatureTask?.cancel()
        lspFeatureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncLanguageServerDocument(forceReopen: false)
            do {
                let edits = try await AppComposition.shared.languageServer.rename(
                    document: self.lspDocumentIdentity(),
                    position: position,
                    newName: trimmed
                )
                guard Task.isCancelled == false else { return }
                guard edits.isEmpty == false else {
                    self.session.hoverText = "Rename returned no edits for this file."
                    return
                }
                let updated = try TextEditApplier.apply(edits, to: self.session.text)
                self.session.applyFileText(updated)
                self.handleTextEdit(updated)
                self.session.hoverText = "Renamed (\(edits.count) edits)."
            } catch {
                guard Task.isCancelled == false else { return }
                self.session.hoverText = error.localizedDescription
                AppLog.lsp.error("rename failed \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func beginApprovedCommand() {
        session.dismissTransientOverlays()
        session.workingDirectoryHint = fileURL?.deletingLastPathComponent().path
        if session.approvedCommandDraft.isEmpty {
            session.approvedCommandDraft = "git status --short"
        }
        session.isApprovedCommandPresented = true
    }

    @MainActor
    private func confirmApprovedCommand(_ command: String) {
        session.isApprovedCommandPresented = false
        do {
            try AppComposition.shared.toolPermissions.require(
                .runCommand,
                allowPromptGrant: true
            )
            let cwd = fileURL?.deletingLastPathComponent().path
            let result = try ApprovedCommandRunner.run(command, workingDirectory: cwd)
            session.aiResult = AISessionResult(
                title: "Command Result",
                text: result.summary,
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        } catch AIProviderError.permissionDenied {
            session.aiResult = AISessionResult(
                title: "Command Result",
                text: "Permission denied: run command.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        } catch ApprovedCommandError.timedOut {
            session.aiResult = AISessionResult(
                title: "Command Result",
                text: "Command timed out.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        } catch {
            session.aiResult = AISessionResult(
                title: "Command Result",
                text: error.localizedDescription,
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        }
    }

    @MainActor
    private func wordNearCaret() -> String {
        let ns = session.text as NSString
        let caret = min(max(session.caretUTF16, 0), ns.length)
        guard ns.length > 0 else { return "" }
        var start = caret
        while start > 0 {
            let ch = ns.character(at: start - 1)
            if Self.isIdentifierCharacter(ch) == false { break }
            start -= 1
        }
        var end = caret
        while end < ns.length {
            let ch = ns.character(at: end)
            if Self.isIdentifierCharacter(ch) == false { break }
            end += 1
        }
        guard end > start else { return "" }
        return ns.substring(with: NSRange(location: start, length: end - start))
    }

    private static func isIdentifierCharacter(_ utf16: unichar) -> Bool {
        (utf16 >= 48 && utf16 <= 57) // 0-9
            || (utf16 >= 65 && utf16 <= 90) // A-Z
            || (utf16 >= 97 && utf16 <= 122) // a-z
            || utf16 == 95 // _
    }

    @MainActor
    private func beginAIAction(_ kind: AIActionKind) {
        if kind == .askAboutFile {
            beginAskAboutFile()
            return
        }
        if kind == .fixDiagnostic {
            beginFixDiagnostic()
            return
        }

        let selection = selectedText()
        let range = session.selectionUTF16
        guard selection.isEmpty == false, range.count > 0 else {
            session.aiResult = AISessionResult(
                title: kindTitle(kind),
                text: "Select some text first.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
            return
        }
        presentAIDisclosure(
            kind: kind,
            selection: selection,
            selectionRange: range,
            disclosure: ContextDisclosure(
                filePath: fileURL?.path,
                selectedCharacterCount: selection.count,
                includesDiagnostics: false,
                includesRepositoryContext: false,
                includesCommandOutput: false
            ),
            diagnosticsText: nil,
            fileText: nil
        )
    }

    @MainActor
    private func beginAskAboutFile() {
        let text = session.text
        guard text.isEmpty == false else {
            session.aiResult = AISessionResult(
                title: "Ask About This File",
                text: "The file is empty.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
            return
        }
        let range = 0..<(text as NSString).length
        presentAIDisclosure(
            kind: .askAboutFile,
            selection: String(text.prefix(2_000)),
            selectionRange: range,
            disclosure: ContextDisclosure(
                filePath: fileURL?.path,
                selectedCharacterCount: text.count,
                includesDiagnostics: session.diagnostics.isEmpty == false,
                includesRepositoryContext: false,
                includesCommandOutput: false
            ),
            diagnosticsText: diagnosticsSummary(),
            fileText: text
        )
    }

    @MainActor
    private func beginFixDiagnostic() {
        guard let diagnostic = diagnosticNearCaret() else {
            session.aiResult = AISessionResult(
                title: "Fix Diagnostic",
                text: "No diagnostic under the caret. Open a file with LSP diagnostics first.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
            return
        }
        let range: Range<Int>
        let selection: String
        if let utf16 = diagnostic.utf16Range, utf16.count > 0 {
            range = utf16
            selection = selectedText(in: utf16)
        } else {
            range = session.selectionUTF16
            selection = selectedText()
        }
        guard selection.isEmpty == false else {
            session.aiResult = AISessionResult(
                title: "Fix Diagnostic",
                text: "Could not resolve text for the diagnostic. Select the problematic span and retry.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
            return
        }
        let summary = "L\(diagnostic.line):\(diagnostic.column) \(diagnostic.severity.rawValue): \(diagnostic.message)"
        presentAIDisclosure(
            kind: .fixDiagnostic,
            selection: selection,
            selectionRange: range,
            disclosure: ContextDisclosure(
                filePath: fileURL?.path,
                selectedCharacterCount: selection.count,
                includesDiagnostics: true,
                includesRepositoryContext: false,
                includesCommandOutput: false
            ),
            diagnosticsText: summary,
            fileText: nil
        )
    }

    @MainActor
    private func presentAIDisclosure(
        kind: AIActionKind,
        selection: String,
        selectionRange: Range<Int>,
        disclosure: ContextDisclosure,
        diagnosticsText: String?,
        fileText: String?
    ) {
        session.isPalettePresented = false
        session.isGoToLinePresented = false
        session.isFindPresented = false
        session.isCompletionPresented = false
        session.isAIResultPresented = false
        session.isAgentPlanPresented = false
        session.hoverText = nil
        session.diagnosticHover = nil
        session.aiResult = nil
        session.agentPlan = nil
        session.ghostSuggestion = nil
        session.aiPendingAction = AIPendingAction(
            kind: kind,
            selection: selection,
            selectionRange: selectionRange,
            disclosure: disclosure,
            diagnosticsText: diagnosticsText,
            fileText: fileText
        )
        session.isAIDisclosurePresented = true
    }

    @MainActor
    private func confirmAIDisclosure() {
        guard let pending = session.aiPendingAction else { return }
        session.isAIDisclosurePresented = false
        let request = AIRequest(
            instruction: pending.instruction,
            selectedText: pending.selection,
            fileText: pending.fileText,
            diagnosticsText: pending.diagnosticsText,
            disclosure: pending.disclosure
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try AppComposition.shared.toolPermissions.require(
                    .sendToProvider,
                    allowPromptGrant: true
                )
                if pending.disclosure.includesDiagnostics {
                    try AppComposition.shared.toolPermissions.require(
                        .readDiagnostics,
                        allowPromptGrant: true
                    )
                }
                if pending.fileText != nil {
                    try AppComposition.shared.toolPermissions.require(
                        .readCurrentFile,
                        allowPromptGrant: true
                    )
                }
                let response = try await AppComposition.shared.aiProvider.complete(request)
                self.session.aiResult = AISessionResult(
                    title: pending.title,
                    text: response.text,
                    proposedEdit: response.proposedEdit,
                    originalText: response.proposedEdit == nil ? nil : pending.selection,
                    selectionRange: pending.selectionRange
                )
                self.session.isAIResultPresented = true
                self.session.aiPendingAction = nil
            } catch AIProviderError.notConfigured {
                self.session.aiResult = AISessionResult(
                    title: pending.title,
                    text: "AI is not configured.",
                    proposedEdit: nil,
                    selectionRange: pending.selectionRange
                )
                self.session.isAIResultPresented = true
                self.session.aiPendingAction = nil
            } catch AIProviderError.missingAPIKey {
                self.session.aiResult = AISessionResult(
                    title: pending.title,
                    text: "HTTP provider is enabled but no API key is stored. Add one in Settings or disable HTTP provider.",
                    proposedEdit: nil,
                    selectionRange: pending.selectionRange
                )
                self.session.isAIResultPresented = true
                self.session.aiPendingAction = nil
            } catch AIProviderError.permissionDenied {
                self.session.aiResult = AISessionResult(
                    title: pending.title,
                    text: "Permission denied.",
                    proposedEdit: nil,
                    selectionRange: pending.selectionRange
                )
                self.session.isAIResultPresented = true
                self.session.aiPendingAction = nil
            } catch {
                self.session.aiResult = AISessionResult(
                    title: pending.title,
                    text: error.localizedDescription,
                    proposedEdit: nil,
                    selectionRange: pending.selectionRange
                )
                self.session.isAIResultPresented = true
                self.session.aiPendingAction = nil
            }
        }
    }

    @MainActor
    private func applyAIEdit() {
        guard let result = session.aiResult, let proposed = result.proposedEdit else { return }
        do {
            try AppComposition.shared.toolPermissions.require(
                .applyEdits,
                allowPromptGrant: true
            )
            let newText = try TextPatchApplier.replaceUTF16Range(
                in: session.text,
                range: result.selectionRange,
                with: proposed
            )
            session.applyFileText(newText)
            handleTextEdit(newText)
            let inserted = (proposed as NSString).length
            session.pendingCaretUTF16 = result.selectionRange.lowerBound + inserted
            session.selectionUTF16 =
                result.selectionRange.lowerBound..<(result.selectionRange.lowerBound + inserted)
            session.isAIResultPresented = false
            session.aiResult = nil
        } catch AIProviderError.permissionDenied {
            session.aiResult = AISessionResult(
                title: result.title,
                text: "Permission denied: apply edits.",
                proposedEdit: proposed,
                originalText: result.originalText,
                selectionRange: result.selectionRange
            )
        } catch {
            session.aiResult = AISessionResult(
                title: result.title,
                text: error.localizedDescription,
                proposedEdit: proposed,
                originalText: result.originalText,
                selectionRange: result.selectionRange
            )
        }
    }

    @MainActor
    private func requestInlineSuggestion() {
        guard session.settings.enableInlineGhostText else { return }
        guard session.selectionUTF16.count == 0 else {
            session.ghostSuggestion = nil
            return
        }
        let caret = session.caretUTF16
        let ns = session.text as NSString
        let clamped = min(max(caret, 0), ns.length)
        let prefix = ns.substring(to: clamped)
        let suffix = ns.substring(from: clamped)
        let disclosure = ContextDisclosure(
            filePath: fileURL?.path,
            selectedCharacterCount: 0,
            includesDiagnostics: false,
            includesRepositoryContext: false,
            includesCommandOutput: false
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try AppComposition.shared.toolPermissions.require(
                    .sendToProvider,
                    allowPromptGrant: true
                )
                let suggestion = try await AppComposition.shared.aiProvider.inlineComplete(
                    InlineCompletionRequest(
                        prefix: prefix,
                        suffix: suffix,
                        languageID: self.session.language.id,
                        disclosure: disclosure
                    )
                )
                guard self.session.caretUTF16 == clamped else { return }
                self.session.ghostSuggestion = suggestion.map {
                    GhostSuggestion(text: $0.text, anchorUTF16: clamped)
                }
            } catch {
                self.session.ghostSuggestion = nil
            }
        }
    }

    @MainActor
    private func scheduleInlineSuggestion() {
        ghostTask?.cancel()
        session.ghostSuggestion = nil
        guard session.settings.enableInlineGhostText else { return }
        ghostTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard Task.isCancelled == false else { return }
            self?.requestInlineSuggestion()
        }
    }

    @MainActor
    private func acceptGhost(_ mode: GhostAcceptMode) {
        guard let ghost = session.ghostSuggestion else { return }
        let insert = mode == .word ? ghost.firstWord : ghost.text
        guard insert.isEmpty == false else {
            session.ghostSuggestion = nil
            return
        }
        let range = ghost.anchorUTF16..<ghost.anchorUTF16
        do {
            let newText = try TextPatchApplier.replaceUTF16Range(
                in: session.text,
                range: range,
                with: insert
            )
            session.applyFileText(newText)
            handleTextEdit(newText)
            let inserted = (insert as NSString).length
            session.pendingCaretUTF16 = ghost.anchorUTF16 + inserted
            if mode == .word, insert != ghost.text {
                let remainder = String(ghost.text.dropFirst(insert.count))
                session.ghostSuggestion = GhostSuggestion(
                    text: remainder,
                    anchorUTF16: ghost.anchorUTF16 + inserted
                )
            } else {
                session.ghostSuggestion = nil
            }
        } catch {
            session.ghostSuggestion = nil
        }
    }

    @MainActor
    private func beginAgentPlan() {
        let selection = selectedText()
        let range = session.selectionUTF16
        guard selection.isEmpty == false, range.count > 0 else {
            session.aiResult = AISessionResult(
                title: "Run Agent",
                text: "Select some text first.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
            return
        }
        session.dismissTransientOverlays()
        session.agentPlan = AppComposition.shared.agentOrchestrator.makeImproveSelectionPlan(
            selection: selection,
            selectionRange: range,
            diagnostics: session.diagnostics,
            filePath: fileURL?.path,
            includeGit: fileURL != nil,
            includeWorkspaceSearch: false
        )
        session.isAgentPlanPresented = true
    }

    @MainActor
    private func showGitStatus() {
        do {
            try AppComposition.shared.toolPermissions.require(
                .inspectGit,
                allowPromptGrant: true
            )
            let snapshot = try GitStatusReader.snapshot(startingAt: fileURL?.path)
            session.aiResult = AISessionResult(
                title: "Git Status",
                text: snapshot.summary.isEmpty ? "Clean working tree (or no changes)." : snapshot.summary,
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        } catch AIProviderError.permissionDenied {
            session.aiResult = AISessionResult(
                title: "Git Status",
                text: "Permission denied: inspect Git.",
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        } catch {
            session.aiResult = AISessionResult(
                title: "Git Status",
                text: error.localizedDescription,
                proposedEdit: nil,
                selectionRange: 0..<0
            )
            session.isAIResultPresented = true
        }
    }

    @MainActor
    private func refreshGitFileStatus() {
        let path = fileURL?.path
        let id = recoveryID
        Task.detached {
            let mark = GitStatusReader.fileMark(for: path)
            await MainActor.run {
                Self.registered(id: id)?.session.gitStatusLabel = mark.statusLabel
            }
        }
    }

    @MainActor
    private func shareFile() {
        guard let url = fileURL,
              let window = windowControllers.first?.window,
              let view = window.contentView
        else {
            session.hoverText = "Save the file first to share it."
            return
        }
        let picker = NSSharingServicePicker(items: [url])
        sharingPicker = picker
        let rect = NSRect(x: view.bounds.midX, y: 8, width: 1, height: 1)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    @MainActor
    private func confirmAgentPlan() {
        guard let plan = session.agentPlan else { return }
        let selection = selectedText(in: plan.selectionRange)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let updated = await AppComposition.shared.agentOrchestrator.run(
                plan: plan,
                selection: selection,
                diagnostics: self.session.diagnostics,
                filePath: self.fileURL?.path,
                permissions: AppComposition.shared.toolPermissions,
                provider: AppComposition.shared.aiProvider,
                allowPromptGrant: true
            )
            self.session.agentPlan = updated
            self.session.isAgentPlanPresented = true
        }
    }

    @MainActor
    private func applyAgentEdit() {
        guard let plan = session.agentPlan, let proposed = plan.proposedEdit else { return }
        do {
            try AppComposition.shared.toolPermissions.require(
                .applyEdits,
                allowPromptGrant: true
            )
            let original = selectedText(in: plan.selectionRange)
            let newText = try TextPatchApplier.replaceUTF16Range(
                in: session.text,
                range: plan.selectionRange,
                with: proposed
            )
            session.applyFileText(newText)
            handleTextEdit(newText)
            let inserted = (proposed as NSString).length
            session.pendingCaretUTF16 = plan.selectionRange.lowerBound + inserted
            session.isAgentPlanPresented = false
            session.agentPlan = nil
            // Surface a final diff confirmation history entry via result overlay optional — keep simple.
            _ = original
        } catch {
            var failed = plan
            if let index = failed.steps.lastIndex(where: { $0.toolCall?.toolName == "apply_patch" }) {
                failed.steps[index].status = .failed
                failed.steps[index].detail = error.localizedDescription
            }
            failed.summary = error.localizedDescription
            session.agentPlan = failed
        }
    }

    @MainActor
    private func kindTitle(_ kind: AIActionKind) -> String {
        switch kind {
        case .explain: return "Explain Selection"
        case .edit: return "Edit Selection"
        case .document: return "Document Selection"
        case .fixDiagnostic: return "Fix Diagnostic"
        case .askAboutFile: return "Ask About This File"
        case .generate: return "Generate from Selection"
        }
    }

    @MainActor
    private func selectedText() -> String {
        selectedText(in: session.selectionUTF16)
    }

    @MainActor
    private func selectedText(in range: Range<Int>) -> String {
        guard range.count > 0 else { return "" }
        let ns = session.text as NSString
        let location = min(max(range.lowerBound, 0), ns.length)
        let length = min(max(range.count, 0), ns.length - location)
        guard length > 0 else { return "" }
        return ns.substring(with: NSRange(location: location, length: length))
    }

    @MainActor
    private func diagnosticNearCaret() -> Diagnostic? {
        let caret = session.caretUTF16
        if let match = session.diagnostics.first(where: { $0.utf16Range?.contains(caret) == true }) {
            return match
        }
        return session.diagnostics.first
    }

    @MainActor
    private func diagnosticsSummary() -> String? {
        guard session.diagnostics.isEmpty == false else { return nil }
        return session.diagnostics
            .prefix(20)
            .map { "L\($0.line):\($0.column) \($0.severity.rawValue): \($0.message)" }
            .joined(separator: "\n")
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
