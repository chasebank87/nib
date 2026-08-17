import Foundation

public struct AICapabilities: Equatable, Sendable {
    public var inlineCompletion: Bool
    public var chat: Bool
    public var tools: Bool

    public init(inlineCompletion: Bool = false, chat: Bool = false, tools: Bool = false) {
        self.inlineCompletion = inlineCompletion
        self.chat = chat
        self.tools = tools
    }

    public static let none = AICapabilities()
}

public struct ContextDisclosure: Equatable, Sendable {
    public var filePath: String?
    public var selectedCharacterCount: Int
    public var includesDiagnostics: Bool
    public var includesRepositoryContext: Bool
    public var includesCommandOutput: Bool

    public init(
        filePath: String? = nil,
        selectedCharacterCount: Int = 0,
        includesDiagnostics: Bool = false,
        includesRepositoryContext: Bool = false,
        includesCommandOutput: Bool = false
    ) {
        self.filePath = filePath
        self.selectedCharacterCount = selectedCharacterCount
        self.includesDiagnostics = includesDiagnostics
        self.includesRepositoryContext = includesRepositoryContext
        self.includesCommandOutput = includesCommandOutput
    }
}

public struct AIRequest: Equatable, Sendable {
    public var id: UUID
    public var instruction: String
    public var selectedText: String
    public var fileText: String?
    public var diagnosticsText: String?
    public var disclosure: ContextDisclosure

    public init(
        id: UUID = UUID(),
        instruction: String,
        selectedText: String,
        fileText: String? = nil,
        diagnosticsText: String? = nil,
        disclosure: ContextDisclosure
    ) {
        self.id = id
        self.instruction = instruction
        self.selectedText = selectedText
        self.fileText = fileText
        self.diagnosticsText = diagnosticsText
        self.disclosure = disclosure
    }
}

public struct AIResponse: Equatable, Sendable {
    public var text: String
    public var proposedEdit: String?

    public init(text: String, proposedEdit: String? = nil) {
        self.text = text
        self.proposedEdit = proposedEdit
    }
}

public struct InlineCompletionRequest: Equatable, Sendable {
    public var id: UUID
    public var prefix: String
    public var suffix: String
    public var languageID: String
    public var disclosure: ContextDisclosure

    public init(
        id: UUID = UUID(),
        prefix: String,
        suffix: String = "",
        languageID: String = "plaintext",
        disclosure: ContextDisclosure
    ) {
        self.id = id
        self.prefix = prefix
        self.suffix = suffix
        self.languageID = languageID
        self.disclosure = disclosure
    }
}

public struct GhostSuggestion: Equatable, Sendable {
    public var text: String
    public var anchorUTF16: Int

    public init(text: String, anchorUTF16: Int) {
        self.text = text
        self.anchorUTF16 = anchorUTF16
    }

    /// First whitespace-delimited token (keeps leading whitespace from the suggestion).
    public var firstWord: String {
        let leading = text.prefix(while: \.isWhitespace)
        let rest = text.dropFirst(leading.count)
        let word = rest.prefix(while: { $0.isWhitespace == false })
        return String(leading + word)
    }
}

public struct ToolPermission: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let readCurrentFile = ToolPermission(rawValue: 1 << 0)
    public static let readNearbyContext = ToolPermission(rawValue: 1 << 1)
    public static let searchWorkspace = ToolPermission(rawValue: 1 << 2)
    public static let readDiagnostics = ToolPermission(rawValue: 1 << 3)
    public static let applyEdits = ToolPermission(rawValue: 1 << 4)
    public static let runCommand = ToolPermission(rawValue: 1 << 5)
    public static let inspectGit = ToolPermission(rawValue: 1 << 6)
    public static let sendToProvider = ToolPermission(rawValue: 1 << 7)

    public static let none: ToolPermission = []
}

public struct AgentToolCall: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var toolName: String
    public var argumentsDescription: String
    public var requiredPermission: ToolPermission

    public init(
        id: UUID = UUID(),
        toolName: String,
        argumentsDescription: String,
        requiredPermission: ToolPermission
    ) {
        self.id = id
        self.toolName = toolName
        self.argumentsDescription = argumentsDescription
        self.requiredPermission = requiredPermission
    }
}

/// Never send source without disclosure + `sendToProvider`.
public protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: AICapabilities { get }
    func complete(_ request: AIRequest) async throws -> AIResponse
    func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion?
}

public extension AIProvider {
    func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        _ = request
        return nil
    }
}

/// Execute only after the matching ToolPermission is granted (NIB-015).
public protocol AgentTool: Sendable {
    var name: String { get }
    var requiredPermission: ToolPermission { get }
}

public enum AgentStepStatus: String, Equatable, Sendable {
    case pending
    case running
    case waitingPermission
    case completed
    case failed
    case skipped
}

public struct AgentPlanStep: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var detail: String
    public var status: AgentStepStatus
    public var toolCall: AgentToolCall?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        status: AgentStepStatus = .pending,
        toolCall: AgentToolCall? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.toolCall = toolCall
    }
}

public struct AgentPlan: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var goal: String
    public var steps: [AgentPlanStep]
    public var proposedEdit: String?
    public var selectionRange: Range<Int>
    public var summary: String?

    public init(
        id: UUID = UUID(),
        goal: String,
        steps: [AgentPlanStep],
        proposedEdit: String? = nil,
        selectionRange: Range<Int> = 0..<0,
        summary: String? = nil
    ) {
        self.id = id
        self.goal = goal
        self.steps = steps
        self.proposedEdit = proposedEdit
        self.selectionRange = selectionRange
        self.summary = summary
    }
}

/// Production Keychain store: `KeychainSecretStore` (NIB-014). Never log secret bytes.
public protocol SecretStoring: Sendable {
    func store(account: String, secret: Data) throws
    func retrieve(account: String) throws -> Data?
    func delete(account: String) throws
}

public enum UnconfiguredAIProvider: AIProvider {
    public static let shared = UnconfiguredAIProvider.instance

    case instance

    public var id: String { "unconfigured" }
    public var displayName: String { "Not configured" }
    public var capabilities: AICapabilities { .none }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        _ = request
        throw AIProviderError.notConfigured
    }

    public func inlineComplete(_ request: InlineCompletionRequest) async throws -> GhostSuggestion? {
        _ = request
        throw AIProviderError.notConfigured
    }
}

public enum AIProviderError: Error, Equatable, Sendable {
    case notConfigured
    case cancelled
    case permissionDenied(ToolPermission)
    case httpStatus(Int)
    case invalidResponse
    case missingAPIKey
}
