import Foundation

public struct EditorCommand: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var keywords: [String]

    public init(id: String, title: String, keywords: [String] = []) {
        self.id = id
        self.title = title
        self.keywords = keywords
    }
}

public enum BuiltInCommandID {
    public static let open = "file.open"
    public static let save = "file.save"
    public static let saveAs = "file.saveAs"
    public static let toggleAppearance = "view.toggleAppearance"
    public static let togglePalette = "view.togglePalette"
}

public enum CommandFilter {
    public static func matches(_ command: EditorCommand, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let haystacks = ([command.title, command.id] + command.keywords).map { $0.lowercased() }
        let needle = trimmed.lowercased()
        return haystacks.contains { $0.contains(needle) || fuzzy($0, needle: needle) }
    }

    /// Subsequence match: "tapp" matches "Toggle Appearance".
    public static func fuzzy(_ haystack: String, needle: String) -> Bool {
        if needle.isEmpty { return true }
        var search = haystack[...]
        for character in needle {
            guard let found = search.firstIndex(of: character) else { return false }
            search = search[search.index(after: found)...]
        }
        return true
    }
}
