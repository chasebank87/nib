import Foundation

public struct LineColumn: Equatable, Sendable {
    /// 1-based line index.
    public var line: Int
    /// 1-based column index in Unicode scalars on that line.
    public var column: Int

    public init(line: Int, column: Int = 1) {
        self.line = line
        self.column = column
    }
}

public enum LineColumnParser {
    /// Accepts `12`, `12:4`, `12,4`. Whitespace is ignored.
    public static func parse(_ raw: String) -> LineColumn? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let separators = CharacterSet(charactersIn: ":,")
        let parts = trimmed.components(separatedBy: separators)
        guard let linePart = parts.first, let line = Int(linePart), line > 0 else {
            return nil
        }
        if parts.count == 1 {
            return LineColumn(line: line, column: 1)
        }
        guard parts.count == 2, let column = Int(parts[1]), column > 0 else {
            return nil
        }
        return LineColumn(line: line, column: column)
    }

    public static func clamp(_ target: LineColumn, in text: String) -> LineColumn {
        let lines = Self.lines(in: text)
        let line = min(max(target.line, 1), lines.count)
        let lineText = lines[line - 1]
        let column = min(max(target.column, 1), lineText.count + 1)
        return LineColumn(line: line, column: column)
    }

    public static func utf16Offset(of target: LineColumn, in text: String) -> Int {
        let clamped = clamp(target, in: text)
        let lines = Self.lines(in: text)
        var offset = 0
        if clamped.line > 1 {
            for index in 0..<(clamped.line - 1) {
                offset += lines[index].utf16.count + 1
            }
        }
        let lineText = lines[clamped.line - 1]
        let prefix = lineText.prefix(clamped.column - 1)
        offset += String(prefix).utf16.count
        return offset
    }

    /// LSP uses 0-based line/character UTF-16 offsets.
    public static func lspPosition(utf16Offset: Int, in text: String) -> LSPPosition {
        let ns = text as NSString
        let clamped = min(max(utf16Offset, 0), ns.length)
        var line = 0
        var lastLineStart = 0
        for index in 0..<clamped {
            if ns.character(at: index) == 10 { // \n
                line += 1
                lastLineStart = index + 1
            }
        }
        return LSPPosition(line: line, character: clamped - lastLineStart)
    }

    /// Converts an LSP 0-based line/character into a UTF-16 buffer offset.
    public static func utf16Offset(lspLine: Int, lspCharacter: Int, in text: String) -> Int {
        let ns = text as NSString
        var line = 0
        var index = 0
        while index < ns.length, line < lspLine {
            if ns.character(at: index) == 10 {
                line += 1
            }
            index += 1
        }
        let lineStart = index
        var character = 0
        while index < ns.length, character < lspCharacter {
            if ns.character(at: index) == 10 { break }
            index += 1
            character += 1
        }
        _ = lineStart
        return min(index, ns.length)
    }

    public static func lineCount(in text: String) -> Int {
        lines(in: text).count
    }

    static func lines(in text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
