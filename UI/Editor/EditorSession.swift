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
    @Published public var isCompletionPresented: Bool
    @Published public var isAIDisclosurePresented: Bool
    @Published public var isAIResultPresented: Bool
    @Published public var isAgentPlanPresented: Bool
    @Published public var caretUTF16: Int
    @Published public var selectionUTF16: Range<Int>
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
    @Published public var diagnostics: [Diagnostic]
    @Published public var completions: [CompletionItem]
    @Published public var hoverText: String?
    @Published public var diagnosticHover: DiagnosticHover?
    @Published public var ghostSuggestion: GhostSuggestion?
    @Published public var aiPendingAction: AIPendingAction?
    @Published public var aiResult: AISessionResult?
    @Published public var agentPlan: AgentPlan?
    @Published public var lspStatus: String

    public let commands = CommandRegistry()

    public var onOpen: () -> Void
    public var onSave: () -> Void
    public var onSaveAs: () -> Void
    public var onTextChange: (String) -> Void
    public var onOpenURLs: ([URL]) -> Void
    public var onLanguageOverride: (String?) -> Void
    public var onFindReplaceAll: (FindOptions) -> Void
    public var onRequestCompletions: () -> Void
    public var onInsertCompletion: (CompletionItem) -> Void
    public var onRequestHover: () -> Void
    public var onRequestInlineSuggestion: () -> Void
    public var onAcceptGhost: (GhostAcceptMode) -> Void
    public var onDismissGhost: () -> Void
    public var onAIAction: (AIActionKind) -> Void
    public var onConfirmAIDisclosure: () -> Void
    public var onApplyAIEdit: () -> Void
    public var onRunAgentPlan: () -> Void
    public var onConfirmAgentPlan: () -> Void
    public var onApplyAgentEdit: () -> Void

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
        onFindReplaceAll: @escaping (FindOptions) -> Void = { _ in },
        onRequestCompletions: @escaping () -> Void = {},
        onInsertCompletion: @escaping (CompletionItem) -> Void = { _ in },
        onRequestHover: @escaping () -> Void = {},
        onRequestInlineSuggestion: @escaping () -> Void = {},
        onAcceptGhost: @escaping (GhostAcceptMode) -> Void = { _ in },
        onDismissGhost: @escaping () -> Void = {},
        onAIAction: @escaping (AIActionKind) -> Void = { _ in },
        onConfirmAIDisclosure: @escaping () -> Void = {},
        onApplyAIEdit: @escaping () -> Void = {},
        onRunAgentPlan: @escaping () -> Void = {},
        onConfirmAgentPlan: @escaping () -> Void = {},
        onApplyAgentEdit: @escaping () -> Void = {}
    ) {
        self.text = text
        self.isPalettePresented = isPalettePresented
        self.isGoToLinePresented = isGoToLinePresented
        self.isFindPresented = isFindPresented
        self.isCompletionPresented = false
        self.isAIDisclosurePresented = false
        self.isAIResultPresented = false
        self.isAgentPlanPresented = false
        self.caretUTF16 = 0
        self.selectionUTF16 = 0..<0
        self.settings = settings
        self.theme = theme
        self.language = language
        self.capabilities = capabilities
        self.syntaxCaptures = []
        self.findOptions = FindOptions()
        self.findMatches = []
        self.diagnostics = []
        self.completions = []
        self.lspStatus = "LSP off"
        self.onOpen = onOpen
        self.onSave = onSave
        self.onSaveAs = onSaveAs
        self.onTextChange = onTextChange
        self.onOpenURLs = onOpenURLs
        self.onLanguageOverride = onLanguageOverride
        self.onFindReplaceAll = onFindReplaceAll
        self.onRequestHover = onRequestHover
        self.onRequestCompletions = onRequestCompletions
        self.onInsertCompletion = onInsertCompletion
        self.onRequestInlineSuggestion = onRequestInlineSuggestion
        self.onAcceptGhost = onAcceptGhost
        self.onDismissGhost = onDismissGhost
        self.onAIAction = onAIAction
        self.onConfirmAIDisclosure = onConfirmAIDisclosure
        self.onApplyAIEdit = onApplyAIEdit
        self.onRunAgentPlan = onRunAgentPlan
        self.onConfirmAgentPlan = onConfirmAgentPlan
        self.onApplyAgentEdit = onApplyAgentEdit
    }

    public func applyFileText(_ value: String) {
        isApplyingFileText = true
        text = value
        isApplyingFileText = false
    }

    public func applyDiagnostics(_ values: [Diagnostic]) {
        diagnostics = values.map { $0.resolvingUTF16Range(in: text) }
        if let hover = diagnosticHover,
           diagnostics.contains(where: { $0.id == hover.diagnosticID }) == false
        {
            diagnosticHover = nil
        }
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

    public func dismissTransientOverlays() {
        isPalettePresented = false
        isGoToLinePresented = false
        isFindPresented = false
        isCompletionPresented = false
        isAIDisclosurePresented = false
        isAIResultPresented = false
        isAgentPlanPresented = false
        hoverText = nil
        diagnosticHover = nil
        aiPendingAction = nil
        aiResult = nil
        agentPlan = nil
    }

    public func clearGhostIfCaretMoved() {
        guard let ghost = ghostSuggestion else { return }
        if caretUTF16 != ghost.anchorUTF16 || selectionUTF16.count > 0 {
            ghostSuggestion = nil
        }
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

public struct DiagnosticHover: Equatable, Sendable {
    public var diagnosticID: UUID
    public var message: String
    public var severity: DiagnosticSeverity
    public var anchorUTF16: Int

    public init(diagnosticID: UUID, message: String, severity: DiagnosticSeverity, anchorUTF16: Int) {
        self.diagnosticID = diagnosticID
        self.message = message
        self.severity = severity
        self.anchorUTF16 = anchorUTF16
    }
}

public enum AIActionKind: String, Equatable, Sendable {
    case explain
    case edit
    case document
    case fixDiagnostic
    case askAboutFile
    case generate
}

public enum GhostAcceptMode: String, Equatable, Sendable {
    case all
    case word
}

public struct AIPendingAction: Equatable, Sendable {
    public var kind: AIActionKind
    public var selection: String
    public var selectionRange: Range<Int>
    public var disclosure: ContextDisclosure
    public var diagnosticsText: String?
    public var fileText: String?

    public init(
        kind: AIActionKind,
        selection: String,
        selectionRange: Range<Int>,
        disclosure: ContextDisclosure,
        diagnosticsText: String? = nil,
        fileText: String? = nil
    ) {
        self.kind = kind
        self.selection = selection
        self.selectionRange = selectionRange
        self.disclosure = disclosure
        self.diagnosticsText = diagnosticsText
        self.fileText = fileText
    }

    public var title: String {
        switch kind {
        case .explain: return "Explain Selection"
        case .edit: return "Edit Selection"
        case .document: return "Document Selection"
        case .fixDiagnostic: return "Fix Diagnostic"
        case .askAboutFile: return "Ask About This File"
        case .generate: return "Generate from Selection"
        }
    }

    public var instruction: String {
        switch kind {
        case .explain: return "Explain this selection"
        case .edit: return "Edit this selection"
        case .document: return "Document this selection"
        case .fixDiagnostic: return "Fix this diagnostic"
        case .askAboutFile: return "Ask about this file"
        case .generate: return "Generate from this selection"
        }
    }
}

public struct AISessionResult: Equatable, Sendable {
    public var title: String
    public var text: String
    public var proposedEdit: String?
    public var originalText: String?
    public var selectionRange: Range<Int>

    public init(
        title: String,
        text: String,
        proposedEdit: String?,
        originalText: String? = nil,
        selectionRange: Range<Int>
    ) {
        self.title = title
        self.text = text
        self.proposedEdit = proposedEdit
        self.originalText = originalText
        self.selectionRange = selectionRange
    }
}
