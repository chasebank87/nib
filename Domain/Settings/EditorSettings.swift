import Foundation

public struct EditorSettings: Equatable, Sendable, Codable {
    public var fontName: String
    public var fontSize: Double
    public var lineHeight: Double
    public var tabWidth: Int
    public var insertSpaces: Bool
    public var wrapLines: Bool
    public var ligatures: Bool
    public var showLineNumbers: Bool
    public var highlightCurrentLine: Bool
    public var showIndentGuides: Bool
    public var themeID: String?
    /// Master switch for language servers (real auto-detect or demo).
    public var enableLanguageServer: Bool
    /// When true (and language server enabled), use the built-in FakeLSP instead of PATH servers.
    public var enableDemoLanguageServer: Bool
    /// Selected AI backend. `.mock` keeps everything local.
    public var aiProviderKind: AIProviderKind
    /// Model id for the active HTTP provider (OpenAI / OpenRouter / LM Studio / Ollama).
    public var aiModel: String
    /// Optional base URL override; empty uses the provider default.
    public var aiBaseURL: String
    /// When true, idle typing can request inline ghost suggestions from the AI provider.
    public var enableInlineGhostText: Bool
    /// When true, Format Document runs before each save (best-effort; save still proceeds on failure).
    public var formatOnSave: Bool

    /// Legacy toggle mirrored from `aiProviderKind != .mock` for older UI/tests.
    public var enableHTTPProvider: Bool {
        get { aiProviderKind != .mock }
        set {
            if newValue {
                if aiProviderKind == .mock { aiProviderKind = .openAI }
            } else {
                aiProviderKind = .mock
            }
        }
    }

    public init(
        fontName: String = EditorSettings.systemMonospaceName,
        fontSize: Double = 13,
        lineHeight: Double = 1.35,
        tabWidth: Int = 4,
        insertSpaces: Bool = true,
        wrapLines: Bool = false,
        ligatures: Bool = true,
        showLineNumbers: Bool = true,
        highlightCurrentLine: Bool = true,
        showIndentGuides: Bool = false,
        themeID: String? = nil,
        enableLanguageServer: Bool = true,
        enableDemoLanguageServer: Bool = false,
        aiProviderKind: AIProviderKind = .mock,
        aiModel: String = "",
        aiBaseURL: String = "",
        enableInlineGhostText: Bool = true,
        formatOnSave: Bool = false,
        enableHTTPProvider: Bool? = nil
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.tabWidth = tabWidth
        self.insertSpaces = insertSpaces
        self.wrapLines = wrapLines
        self.ligatures = ligatures
        self.showLineNumbers = showLineNumbers
        self.highlightCurrentLine = highlightCurrentLine
        self.showIndentGuides = showIndentGuides
        self.themeID = themeID
        self.enableLanguageServer = enableLanguageServer
        self.enableDemoLanguageServer = enableDemoLanguageServer
        self.aiProviderKind = aiProviderKind
        self.aiModel = aiModel
        self.aiBaseURL = aiBaseURL
        self.enableInlineGhostText = enableInlineGhostText
        self.formatOnSave = formatOnSave
        if let enableHTTPProvider {
            self.enableHTTPProvider = enableHTTPProvider
        }
    }

    public static let `default` = EditorSettings()
    public static let systemMonospaceName = ".AppleSystemUIFontMonospaced"
    public static let recommendedFontNames = [
        systemMonospaceName,
        "Menlo",
        "Monaco",
        "Courier New",
    ]

    public static let storageKey = "editor.settings.v1"

    private enum CodingKeys: String, CodingKey {
        case fontName, fontSize, lineHeight, tabWidth, insertSpaces, wrapLines, ligatures
        case showLineNumbers, highlightCurrentLine, showIndentGuides, themeID
        case enableLanguageServer, enableDemoLanguageServer
        case aiProviderKind, aiModel, aiBaseURL, enableInlineGhostText, formatOnSave
        case enableHTTPProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? Self.default.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? Self.default.fontSize
        lineHeight = try container.decodeIfPresent(Double.self, forKey: .lineHeight) ?? Self.default.lineHeight
        tabWidth = try container.decodeIfPresent(Int.self, forKey: .tabWidth) ?? Self.default.tabWidth
        insertSpaces = try container.decodeIfPresent(Bool.self, forKey: .insertSpaces) ?? Self.default.insertSpaces
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? Self.default.wrapLines
        ligatures = try container.decodeIfPresent(Bool.self, forKey: .ligatures) ?? Self.default.ligatures
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers)
            ?? Self.default.showLineNumbers
        highlightCurrentLine = try container.decodeIfPresent(Bool.self, forKey: .highlightCurrentLine)
            ?? Self.default.highlightCurrentLine
        showIndentGuides = try container.decodeIfPresent(Bool.self, forKey: .showIndentGuides)
            ?? Self.default.showIndentGuides
        themeID = try container.decodeIfPresent(String.self, forKey: .themeID)
        enableLanguageServer = try container.decodeIfPresent(Bool.self, forKey: .enableLanguageServer)
            ?? Self.default.enableLanguageServer
        enableDemoLanguageServer = try container.decodeIfPresent(Bool.self, forKey: .enableDemoLanguageServer)
            ?? Self.default.enableDemoLanguageServer
        if let kind = try container.decodeIfPresent(AIProviderKind.self, forKey: .aiProviderKind) {
            aiProviderKind = kind
        } else if try container.decodeIfPresent(Bool.self, forKey: .enableHTTPProvider) == true {
            aiProviderKind = .openAI
        } else {
            aiProviderKind = .mock
        }
        aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel) ?? ""
        aiBaseURL = try container.decodeIfPresent(String.self, forKey: .aiBaseURL) ?? ""
        enableInlineGhostText = try container.decodeIfPresent(Bool.self, forKey: .enableInlineGhostText)
            ?? Self.default.enableInlineGhostText
        formatOnSave = try container.decodeIfPresent(Bool.self, forKey: .formatOnSave)
            ?? Self.default.formatOnSave
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineHeight, forKey: .lineHeight)
        try container.encode(tabWidth, forKey: .tabWidth)
        try container.encode(insertSpaces, forKey: .insertSpaces)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(ligatures, forKey: .ligatures)
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(highlightCurrentLine, forKey: .highlightCurrentLine)
        try container.encode(showIndentGuides, forKey: .showIndentGuides)
        try container.encodeIfPresent(themeID, forKey: .themeID)
        try container.encode(enableLanguageServer, forKey: .enableLanguageServer)
        try container.encode(enableDemoLanguageServer, forKey: .enableDemoLanguageServer)
        try container.encode(aiProviderKind, forKey: .aiProviderKind)
        try container.encode(aiModel, forKey: .aiModel)
        try container.encode(aiBaseURL, forKey: .aiBaseURL)
        try container.encode(enableInlineGhostText, forKey: .enableInlineGhostText)
        try container.encode(formatOnSave, forKey: .formatOnSave)
        try container.encode(enableHTTPProvider, forKey: .enableHTTPProvider)
    }

    public func sanitized() -> EditorSettings {
        var copy = self
        if copy.fontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.fontName = Self.systemMonospaceName
        }
        copy.fontSize = min(max(copy.fontSize, 9), 32)
        copy.lineHeight = min(max(copy.lineHeight, 1.0), 2.5)
        copy.tabWidth = min(max(copy.tabWidth, 1), 16)
        if let themeID = copy.themeID, themeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.themeID = nil
        }
        copy.aiModel = copy.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.aiBaseURL = copy.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.aiBaseURL.isEmpty == false, URL(string: copy.aiBaseURL) == nil {
            copy.aiBaseURL = ""
        }
        return copy
    }

    public static func decoded(from json: String?) -> EditorSettings {
        guard let json, let data = json.data(using: .utf8) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(EditorSettings.self, from: data).sanitized()
        } catch {
            return .default
        }
    }

    public func encodedJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized()) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func displayName(forFont fontName: String) -> String {
        if fontName == systemMonospaceName {
            return "System Mono"
        }
        return fontName
    }
}
