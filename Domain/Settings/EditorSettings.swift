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
        themeID: String? = nil
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
