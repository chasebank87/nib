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
    public var disclosure: ContextDisclosure

    public init(
        id: UUID = UUID(),
        instruction: String,
        selectedText: String,
        fileText: String? = nil,
        disclosure: ContextDisclosure
    ) {
        self.id = id
        self.instruction = instruction
        self.selectedText = selectedText
        self.fileText = fileText
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

/// TODO(NIB-013): Mock provider first. Never send source without disclosure + sendToProvider.
public protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: AICapabilities { get }
    func complete(_ request: AIRequest) async throws -> AIResponse
}

/// TODO(NIB-015): Execute only after the matching ToolPermission is granted.
public protocol AgentTool: Sendable {
    var name: String { get }
    var requiredPermission: ToolPermission { get }
}

/// TODO(NIB-014): Keychain-backed production store. Never log secret bytes.
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
}

public enum AIProviderError: Error, Equatable, Sendable {
    case notConfigured
    case cancelled
    case permissionDenied(ToolPermission)
}
