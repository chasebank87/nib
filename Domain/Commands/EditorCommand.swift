import Foundation

public struct EditorCommand: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var keywords: [String]
    public var shortcutLabel: String?

    public init(
        id: String,
        title: String,
        keywords: [String] = [],
        shortcutLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.keywords = keywords
        self.shortcutLabel = shortcutLabel
    }
}

public enum BuiltInCommandID {
    public static let new = "file.new"
    public static let open = "file.open"
    public static let save = "file.save"
    public static let saveAs = "file.saveAs"
    public static let revealInFinder = "file.revealInFinder"
    public static let goToLine = "nav.goToLine"
    public static let toggleAppearance = "view.toggleAppearance"
    public static let togglePalette = "view.togglePalette"
    public static let openSettings = "view.openSettings"
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

    /// Empty query preserves registration order. Non-empty queries rank prefix
    /// matches ahead of substring and fuzzy matches.
    public static func ranked(_ commands: [EditorCommand], query: String) -> [EditorCommand] {
        let filtered = commands.filter { matches($0, query: query) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return filtered
        }
        return filtered.enumerated().sorted { lhs, rhs in
            let left = score(lhs.element, query: trimmed)
            let right = score(rhs.element, query: trimmed)
            if left == right {
                return lhs.offset < rhs.offset
            }
            return left < right
        }.map(\.element)
    }

    private static func score(_ command: EditorCommand, query: String) -> Int {
        let title = command.title.lowercased()
        if title == query { return 0 }
        if title.hasPrefix(query) { return 1 }
        if title.contains(query) { return 2 }
        if command.keywords.contains(where: { $0.lowercased().contains(query) }) { return 3 }
        return 4
    }
}

public final class CommandRegistry: @unchecked Sendable {
    private var commands: [EditorCommand] = []
    private var actions: [String: () -> Void] = [:]
    private var predicates: [String: () -> Bool] = [:]

    public init() {}

    public func register(
        _ command: EditorCommand,
        isEnabled: @escaping () -> Bool = { true },
        perform: @escaping () -> Void
    ) {
        commands.removeAll { $0.id == command.id }
        commands.append(command)
        predicates[command.id] = isEnabled
        actions[command.id] = perform
    }

    public func isEnabled(_ id: String) -> Bool {
        predicates[id]?() ?? false
    }

    /// Disabled commands are omitted from the palette.
    public func visibleCommands(matching query: String = "") -> [EditorCommand] {
        let enabled = commands.filter { isEnabled($0.id) }
        return CommandFilter.ranked(enabled, query: query)
    }

    public func perform(_ id: String) {
        guard isEnabled(id) else { return }
        actions[id]?()
    }
}
