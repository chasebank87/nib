import NibDomain
import SwiftUI
import UniformTypeIdentifiers

public struct EditorShellView: View {
    @ObservedObject var session: EditorSession
    let resolveTheme: () -> Theme
    let resolveSettings: () -> EditorSettings

    public init(
        session: EditorSession,
        theme: Theme,
        resolveTheme: @escaping () -> Theme = { Theme.nibDark },
        resolveSettings: @escaping () -> EditorSettings = { .default }
    ) {
        self.session = session
        self.resolveTheme = resolveTheme
        self.resolveSettings = resolveSettings
        session.theme = theme
        session.settings = resolveSettings()
    }

    public var body: some View {
        content
            .frame(minWidth: 480, minHeight: 320)
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
            .modifier(EditorShellNotifications(
                session: session,
                resolveTheme: resolveTheme,
                resolveSettings: resolveSettings
            ))
            .onAppear {
                session.theme = resolveTheme()
                session.settings = resolveSettings()
            }
    }

    private var content: some View {
        ZStack {
            session.theme.color(.editorBackground).ignoresSafeArea()
            editorColumn
            transientOverlays
            aiOverlays
        }
    }

    private var editorColumn: some View {
        VStack(spacing: 0) {
            EditorTextView(
                text: $session.text,
                caretUTF16: $session.caretUTF16,
                selectionUTF16: $session.selectionUTF16,
                pendingCaretUTF16: $session.pendingCaretUTF16,
                pendingSelectionUTF16: $session.pendingSelectionUTF16,
                diagnosticHover: $session.diagnosticHover,
                ghostSuggestion: session.ghostSuggestion,
                theme: session.theme,
                settings: session.settings,
                capabilities: session.capabilities,
                syntaxCaptures: session.syntaxCaptures,
                findMatches: session.findMatches,
                diagnostics: session.diagnostics,
                wrapLines: session.settings.wrapLines
                    && session.capabilities.wrapLines
                    && session.reducedFeatureMessage == nil,
                onAcceptGhost: { session.onAcceptGhost($0) },
                onDismissGhost: { session.onDismissGhost() },
                onCaretMoved: { session.clearGhostIfCaretMoved() }
            )
            statusBar
        }
    }

    @ViewBuilder
    private var transientOverlays: some View {
        if session.isPalettePresented {
            CommandPaletteView(
                theme: session.theme,
                commands: session.commands.visibleCommands(),
                onSelect: { command in
                    session.isPalettePresented = false
                    session.commands.perform(command.id)
                },
                onDismiss: { session.isPalettePresented = false }
            )
        }
        if session.isGoToLinePresented {
            GoToLineView(
                theme: session.theme,
                onGo: { session.goTo($0) },
                onDismiss: { session.isGoToLinePresented = false }
            )
        }
        if session.isFindPresented {
            FindReplaceView(
                options: $session.findOptions,
                status: session.findStatus,
                theme: session.theme,
                onFind: { session.runFind() },
                onReplaceAll: { session.runReplaceAll() },
                onDismiss: {
                    session.isFindPresented = false
                    session.findMatches = []
                    session.findStatus = nil
                }
            )
        }
        if session.isCompletionPresented {
            CompletionOverlayView(
                items: session.completions,
                theme: session.theme,
                onSelect: { session.onInsertCompletion($0) },
                onDismiss: {
                    session.isCompletionPresented = false
                    session.completions = []
                }
            )
        }
        if let hover = session.diagnosticHover {
            diagnosticTooltip(hover)
        } else if let hover = session.hoverText {
            bottomOverlay(text: hover) {
                session.hoverText = nil
            }
        }
    }

    @ViewBuilder
    private var aiOverlays: some View {
        if session.isAIDisclosurePresented, let pending = session.aiPendingAction {
            ContextDisclosureView(
                disclosure: pending.disclosure,
                actionTitle: pending.title,
                theme: session.theme,
                onConfirm: { session.onConfirmAIDisclosure() },
                onCancel: {
                    session.isAIDisclosurePresented = false
                    session.aiPendingAction = nil
                }
            )
        }
        if session.isAIResultPresented, let result = session.aiResult {
            AIResultOverlayView(
                title: result.title,
                text: result.text,
                proposedEdit: result.proposedEdit,
                originalText: result.originalText,
                theme: session.theme,
                onApply: result.proposedEdit == nil ? nil : { session.onApplyAIEdit() },
                onDismiss: {
                    session.isAIResultPresented = false
                    session.aiResult = nil
                }
            )
        }
        if session.isAgentPlanPresented, let plan = session.agentPlan {
            AgentPlanOverlayView(
                plan: plan,
                theme: session.theme,
                onRun: { session.onConfirmAgentPlan() },
                onApply: plan.proposedEdit == nil ? nil : { session.onApplyAgentEdit() },
                onDismiss: {
                    session.isAgentPlanPresented = false
                    session.agentPlan = nil
                }
            )
        }
        if session.isMarkdownPreviewPresented {
            MarkdownPreviewOverlayView(
                source: session.text,
                theme: session.theme,
                onDismiss: { session.isMarkdownPreviewPresented = false }
            )
        }
        if session.isRenamePresented {
            RenameSymbolOverlayView(
                newName: $session.renameDraft,
                theme: session.theme,
                onRename: { session.onConfirmRename($0) },
                onDismiss: { session.isRenamePresented = false }
            )
        }
        if session.isApprovedCommandPresented {
            ApprovedCommandOverlayView(
                command: $session.approvedCommandDraft,
                workingDirectory: session.workingDirectoryHint,
                theme: session.theme,
                onRun: { session.onConfirmApprovedCommand($0) },
                onDismiss: { session.isApprovedCommandPresented = false }
            )
        }
    }

    private var statusBar: some View {
        ZStack {
            HStack(spacing: 8) {
                statusLeading
                Spacer(minLength: 8)
                Text(session.lspStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(session.theme.color(.gutterForeground))
                    .lineLimit(1)
            }

            LanguageMenu(
                language: session.language,
                theme: session.theme,
                onSelect: { session.onLanguageOverride($0) }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(session.theme.color(.gutterBackground))
    }

    @ViewBuilder
    private var statusLeading: some View {
        if let message = session.reducedFeatureMessage {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(session.theme.color(.editorForeground).opacity(0.8))
                .lineLimit(1)
        } else if session.diagnostics.isEmpty == false {
            let errors = session.diagnostics.filter { $0.severity == .error }.count
            let warnings = session.diagnostics.filter { $0.severity == .warning }.count
            Text(issueSummary(errors: errors, warnings: warnings, total: session.diagnostics.count))
                .font(.system(size: 11))
                .foregroundStyle(session.theme.color(.gutterForeground))
                .help("Diagnostics are underlined in the editor — hover a mark for details")
        } else {
            Text(session.languageOverrideID == nil ? "Auto" : "Manual")
                .font(.system(size: 11))
                .foregroundStyle(session.theme.color(.gutterForeground).opacity(0.7))
        }
    }

    private func issueSummary(errors: Int, warnings: Int, total: Int) -> String {
        if errors > 0, warnings > 0 {
            return "\(errors) errors · \(warnings) warnings"
        }
        if errors > 0 {
            return errors == 1 ? "1 error" : "\(errors) errors"
        }
        if warnings > 0 {
            return warnings == 1 ? "1 warning" : "\(warnings) warnings"
        }
        return total == 1 ? "1 issue" : "\(total) issues"
    }

    private func diagnosticTooltip(_ hover: DiagnosticHover) -> some View {
        VStack {
            HStack {
                Text(hover.message)
                    .font(.system(size: 12))
                    .foregroundStyle(session.theme.color(.overlayForeground))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(session.theme.color(.overlayBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(session.theme.color(token(for: hover.severity)), lineWidth: 1)
                    )
                    .padding(.top, 48)
                    .padding(.leading, 56)
                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func bottomOverlay(text: String, onDismiss: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
            HStack {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(session.theme.color(.overlayForeground))
                    .padding(12)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(session.theme.color(.overlayBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(session.theme.color(.overlayBorder), lineWidth: 1)
                    )
                    .padding(16)
                Spacer()
            }
        }
        .transition(.opacity)
        .onTapGesture(perform: onDismiss)
    }

    private func token(for severity: DiagnosticSeverity) -> ThemeToken {
        switch severity {
        case .error: return .diagnosticError
        case .warning: return .diagnosticWarning
        case .information: return .diagnosticInfo
        case .hint: return .diagnosticHint
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var claimed = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                claimed = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let itemURL = item as? URL {
                        url = itemURL
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = nil
                    }
                    guard let url else { return }
                    DispatchQueue.main.async {
                        self.session.onOpenURLs([url])
                    }
                }
            }
        }
        return claimed
    }
}

private struct EditorShellNotifications: ViewModifier {
    @ObservedObject var session: EditorSession
    let resolveTheme: () -> Theme
    let resolveSettings: () -> EditorSettings

    func body(content: Content) -> some View {
        content
            .modifier(EditorShellCoreNotifications(session: session))
            .modifier(EditorShellAINotifications(session: session))
            .onReceive(NotificationCenter.default.publisher(for: .nibAppearanceDidChange)) { _ in
                session.theme = resolveTheme()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibEditorSettingsDidChange)) { _ in
                session.settings = resolveSettings()
                session.theme = resolveTheme()
            }
    }
}

private struct EditorShellCoreNotifications: ViewModifier {
    @ObservedObject var session: EditorSession

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .nibToggleCommandPalette)) { _ in
                session.dismissTransientOverlays()
                session.isPalettePresented.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibGoToLine)) { _ in
                session.dismissTransientOverlays()
                session.isGoToLinePresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibFind)) { _ in
                session.dismissTransientOverlays()
                session.isFindPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibComplete)) { _ in
                session.dismissTransientOverlays()
                session.onRequestCompletions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibHover)) { _ in
                session.isCompletionPresented = false
                session.onRequestHover()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibGoToDefinition)) { _ in
                session.onGoToDefinition()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibFormatDocument)) { _ in
                session.onFormatDocument()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibRenameSymbol)) { _ in
                session.onBeginRename()
            }
    }
}

private struct EditorShellAINotifications: ViewModifier {
    @ObservedObject var session: EditorSession

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .nibExplainSelection)) { _ in
                session.onAIAction(.explain)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibEditSelection)) { _ in
                session.onAIAction(.edit)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibDocumentSelection)) { _ in
                session.onAIAction(.document)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibFixDiagnostic)) { _ in
                session.onAIAction(.fixDiagnostic)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibAskAboutFile)) { _ in
                session.onAIAction(.askAboutFile)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibGenerateSelection)) { _ in
                session.onAIAction(.generate)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibInlineSuggest)) { _ in
                session.onRequestInlineSuggestion()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibRunAgent)) { _ in
                session.onRunAgentPlan()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibMarkdownPreview)) { _ in
                session.dismissTransientOverlays()
                session.isMarkdownPreviewPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibGitStatus)) { _ in
                session.onInspectGit()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nibRunApprovedCommand)) { _ in
                session.onBeginApprovedCommand()
            }
    }
}
