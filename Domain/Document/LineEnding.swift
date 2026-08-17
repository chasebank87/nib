import Foundation

public enum LineEnding: String, Equatable, Sendable, CaseIterable, Codable {
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

    public var displayName: String {
        switch self {
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        }
    }

    /// Picks the most common ending. Ties prefer CRLF, then LF, then CR.
    /// Mixed files are LF-normalized in memory; save uses this ending unless
    /// the buffer is still clean, in which case original bytes are preserved.
    public static func detect(in text: String) -> LineEnding {
        scan(in: text).ending
    }

    public static func scan(in text: String) -> LineEndingScan {
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

        let kinds = [crlfCount, lfCount, crCount].filter { $0 > 0 }.count
        let ending: LineEnding
        if crlfCount == 0, lfCount == 0, crCount == 0 {
            ending = .lf
        } else {
            let maxCount = max(crlfCount, max(lfCount, crCount))
            if crlfCount == maxCount {
                ending = .crlf
            } else if lfCount == maxCount {
                ending = .lf
            } else {
                ending = .cr
            }
        }

        return LineEndingScan(
            ending: ending,
            isMixed: kinds >= 2,
            lfCount: lfCount,
            crlfCount: crlfCount,
            crCount: crCount
        )
    }

    public static func normalizeToLF(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

public struct LineEndingScan: Equatable, Sendable {
    public var ending: LineEnding
    public var isMixed: Bool
    public var lfCount: Int
    public var crlfCount: Int
    public var crCount: Int

    public init(ending: LineEnding, isMixed: Bool, lfCount: Int, crlfCount: Int, crCount: Int) {
        self.ending = ending
        self.isMixed = isMixed
        self.lfCount = lfCount
        self.crlfCount = crlfCount
        self.crCount = crCount
    }
}
