import Foundation

public struct FindOptions: Equatable, Sendable {
    public var query: String
    public var replacement: String
    public var useRegularExpression: Bool
    public var caseSensitive: Bool
    public var wholeWord: Bool
    public var inSelectionOnly: Bool

    public init(
        query: String = "",
        replacement: String = "",
        useRegularExpression: Bool = false,
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        inSelectionOnly: Bool = false
    ) {
        self.query = query
        self.replacement = replacement
        self.useRegularExpression = useRegularExpression
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.inSelectionOnly = inSelectionOnly
    }
}

public enum FindError: Error, Equatable, Sendable {
    case emptyQuery
    case invalidRegularExpression(String)
}

public enum FindReplaceEngine {
    public static func findAll(
        in text: String,
        options: FindOptions,
        selection: Range<String.Index>? = nil
    ) throws -> [Range<String.Index>] {
        let query = options.query
        guard query.isEmpty == false else { throw FindError.emptyQuery }

        let searchRange: Range<String.Index>
        if options.inSelectionOnly, let selection {
            searchRange = selection
        } else {
            searchRange = text.startIndex..<text.endIndex
        }

        if options.useRegularExpression {
            return try regexMatches(in: text, options: options, searchRange: searchRange)
        }
        return literalMatches(in: text, options: options, searchRange: searchRange)
    }

    public static func replaceAll(
        in text: String,
        options: FindOptions,
        selection: Range<String.Index>? = nil
    ) throws -> (text: String, count: Int) {
        let matches = try findAll(in: text, options: options, selection: selection)
        guard matches.isEmpty == false else { return (text, 0) }

        var result = text
        for range in matches.reversed() {
            result.replaceSubrange(range, with: options.replacement)
        }
        return (result, matches.count)
    }

    private static func literalMatches(
        in text: String,
        options: FindOptions,
        searchRange: Range<String.Index>
    ) -> [Range<String.Index>] {
        var matches: [Range<String.Index>] = []
        var compareOptions: String.CompareOptions = []
        if options.caseSensitive == false {
            compareOptions.insert(.caseInsensitive)
        }
        var searchStart = searchRange.lowerBound
        while searchStart < searchRange.upperBound {
            guard let found = text.range(
                of: options.query,
                options: compareOptions,
                range: searchStart..<searchRange.upperBound
            ) else { break }
            if options.wholeWord == false || isWholeWord(found, in: text) {
                matches.append(found)
            }
            searchStart = found.upperBound
        }
        return matches
    }

    private static func regexMatches(
        in text: String,
        options: FindOptions,
        searchRange: Range<String.Index>
    ) throws -> [Range<String.Index>] {
        let pattern = try compiledPattern(options)
        let nsRange = NSRange(searchRange, in: text)
        let matches = pattern.matches(in: text, options: [], range: nsRange)
        return matches.compactMap { match in
            Range(match.range, in: text)
        }
    }

    private static func compiledPattern(_ options: FindOptions) throws -> NSRegularExpression {
        var pattern = options.query
        if options.wholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        var regexOptions: NSRegularExpression.Options = []
        if options.caseSensitive == false {
            regexOptions.insert(.caseInsensitive)
        }
        do {
            return try NSRegularExpression(pattern: pattern, options: regexOptions)
        } catch {
            throw FindError.invalidRegularExpression(error.localizedDescription)
        }
    }

    private static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let word = CharacterSet.alphanumerics.union(.init(charactersIn: "_"))
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous.unicodeScalars.contains(where: { word.contains($0) }) {
                return false
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next.unicodeScalars.contains(where: { word.contains($0) }) {
                return false
            }
        }
        return true
    }
}
