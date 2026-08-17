import Foundation
import NibDomain
import NibTreeSitterC

/// Tree-sitter based highlighter for JSON, Markdown, and Python (NIB-008).
public struct TreeSitterHighlighter: SyntaxHighlighting, @unchecked Sendable {
    private let queryDirectory: URL

    public init(queryDirectory: URL? = nil) {
        if let queryDirectory {
            self.queryDirectory = queryDirectory
        } else if let bundled = Bundle.module.resourceURL?.appendingPathComponent("Queries") {
            self.queryDirectory = bundled
        } else if let main = Bundle.main.resourceURL?.appendingPathComponent("Queries") {
            self.queryDirectory = main
        } else {
            self.queryDirectory = URL(fileURLWithPath: "/")
        }
    }

    public func highlights(for text: String, language: LanguageDescriptor) async throws -> [SyntaxCapture] {
        try Task.checkCancellation()
        guard let languagePtr = Self.languagePointer(for: language.id) else {
            throw SyntaxHighlightError.unsupportedLanguage
        }
        let queryURL = queryDirectory
            .appendingPathComponent(Self.queryFolder(for: language.id))
            .appendingPathComponent("highlights.scm")
        guard let querySource = try? String(contentsOf: queryURL, encoding: .utf8) else {
            throw SyntaxHighlightError.queryFailed("missing highlights.scm for \(language.id)")
        }
        let snapshot = text
        return try await Task.detached(priority: .userInitiated) {
            try Self.parse(text: snapshot, language: languagePtr, querySource: querySource)
        }.value
    }

    public static func supports(_ languageID: String) -> Bool {
        languagePointer(for: languageID) != nil
    }

    private static func queryFolder(for languageID: String) -> String {
        switch languageID {
        case "json": "json"
        case "python": "python"
        case "markdown": "markdown"
        default: languageID
        }
    }

    private static func languagePointer(for languageID: String) -> OpaquePointer? {
        switch languageID {
        case "json":
            return tree_sitter_json()
        case "python":
            return tree_sitter_python()
        case "markdown":
            return tree_sitter_markdown()
        default:
            return nil
        }
    }

    private static func parse(
        text: String,
        language: OpaquePointer,
        querySource: String
    ) throws -> [SyntaxCapture] {
        guard let parser = ts_parser_new() else {
            throw SyntaxHighlightError.queryFailed("parser alloc")
        }
        defer { ts_parser_delete(parser) }

        guard ts_parser_set_language(parser, language) else {
            throw SyntaxHighlightError.queryFailed("set language")
        }

        let utf8Count = text.utf8.count
        let tree = text.withCString { pointer in
            ts_parser_parse_string(parser, nil, pointer, UInt32(utf8Count))
        }
        guard let tree else {
            throw SyntaxHighlightError.queryFailed("parse")
        }
        defer { ts_tree_delete(tree) }

        var errorOffset: UInt32 = 0
        var errorType = TSQueryErrorNone
        let query = querySource.withCString { pointer in
            ts_query_new(
                language,
                pointer,
                UInt32(querySource.utf8.count),
                &errorOffset,
                &errorType
            )
        }
        guard let query else {
            throw SyntaxHighlightError.queryFailed("query error \(Int(errorType.rawValue)) at \(errorOffset)")
        }
        defer { ts_query_delete(query) }

        guard let cursor = ts_query_cursor_new() else {
            throw SyntaxHighlightError.queryFailed("cursor")
        }
        defer { ts_query_cursor_delete(cursor) }

        let root = ts_tree_root_node(tree)
        ts_query_cursor_exec(cursor, query, root)

        var captures: [SyntaxCapture] = []
        var match = TSQueryMatch()
        while ts_query_cursor_next_match(cursor, &match) {
            let count = Int(match.capture_count)
            guard count > 0, let base = match.captures else { continue }
            for index in 0..<count {
                let capture = base.advanced(by: index).pointee
                var nameLength: UInt32 = 0
                guard let namePointer = ts_query_capture_name_for_id(query, capture.index, &nameLength) else {
                    continue
                }
                let scope = String(cString: namePointer)
                let startByte = Int(ts_node_start_byte(capture.node))
                let endByte = Int(ts_node_end_byte(capture.node))
                guard let utf16 = utf16Range(utf8Start: startByte, utf8End: endByte, in: text) else {
                    continue
                }
                captures.append(SyntaxCapture(utf16Range: utf16, scope: scope))
            }
        }

        return captures.sorted { lhs, rhs in
            if lhs.utf16Range.lowerBound == rhs.utf16Range.lowerBound {
                return lhs.utf16Range.count > rhs.utf16Range.count
            }
            return lhs.utf16Range.lowerBound < rhs.utf16Range.lowerBound
        }
    }

    private static func utf16Range(utf8Start: Int, utf8End: Int, in text: String) -> Range<Int>? {
        let utf8 = text.utf8
        guard
            let start = utf8.index(utf8.startIndex, offsetBy: utf8Start, limitedBy: utf8.endIndex),
            let end = utf8.index(utf8.startIndex, offsetBy: utf8End, limitedBy: utf8.endIndex),
            start <= end
        else { return nil }
        let nsRange = NSRange(start..<end, in: text)
        guard nsRange.location != NSNotFound else { return nil }
        return nsRange.location..<(nsRange.location + nsRange.length)
    }
}
