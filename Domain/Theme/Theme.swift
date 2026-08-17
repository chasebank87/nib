import Foundation

public struct Theme: Equatable, Sendable, Identifiable, Codable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var appearance: ThemeAppearance
    public var tokens: [String: String]
    public var syntax: [String: String]

    public init(
        schemaVersion: Int = 1,
        id: String,
        name: String,
        appearance: ThemeAppearance,
        tokens: [String: String],
        syntax: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.appearance = appearance
        self.tokens = tokens
        self.syntax = syntax
    }

    public func hex(for token: ThemeToken) -> String {
        tokens[token.rawValue] ?? Theme.fallbackHex(for: token, appearance: appearance)
    }

    public func token(forSyntaxScope scope: String) -> ThemeToken? {
        var components = scope.split(separator: ".").map(String.init)
        while components.isEmpty == false {
            let key = components.joined(separator: ".")
            if let raw = syntax[key], let token = ThemeToken(rawValue: raw) {
                return token
            }
            if let raw = syntax[components[components.count - 1]], let token = ThemeToken(rawValue: raw) {
                return token
            }
            components.removeLast()
        }
        return nil
    }

    public static func fallbackHex(for token: ThemeToken, appearance: ThemeAppearance) -> String {
        switch appearance {
        case .light:
            switch token {
            case .editorBackground, .gutterBackground: "#F5F5F7"
            case .editorForeground, .cursor, .syntaxVariable, .overlayForeground, .paletteForeground: "#1D1D1F"
            default: "#86868B"
            }
        case .dark:
            switch token {
            case .editorBackground, .gutterBackground: "#1C1C1E"
            case .editorForeground, .cursor, .syntaxVariable, .overlayForeground, .paletteForeground: "#F5F5F7"
            default: "#98989D"
            }
        }
    }
}

public enum ThemeCodec {
    public static func decode(_ data: Data) throws -> Theme {
        let decoder = JSONDecoder()
        return try decoder.decode(Theme.self, from: data)
    }

    public static func encode(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(theme)
    }
}
