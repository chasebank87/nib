import Foundation

public enum LineEnding: String, Equatable, Sendable, CaseIterable {
    case lf
    case crlf
    case cr

    public var sequence: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }

    /// Picks the most common ending. Ties prefer CRLF, then LF, then CR.
    /// Mixed files are normalized on load; this is the ending used on save.
    public static func detect(in text: String) -> LineEnding {
        var crlfCount = 0
        var lfCount = 0
        var crCount = 0

        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\r" {
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    crlfCount += 1
                    index += 2
                    continue
                }
                crCount += 1
            } else if scalar == "\n" {
                lfCount += 1
            }
            index += 1
        }

        if crlfCount == 0, lfCount == 0, crCount == 0 {
            return .lf
        }

        let maxCount = max(crlfCount, max(lfCount, crCount))
        if crlfCount == maxCount {
            return .crlf
        }
        if lfCount == maxCount {
            return .lf
        }
        return .cr
    }

    public static func normalizeToLF(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
