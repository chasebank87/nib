import Foundation

public enum DiffLineKind: String, Equatable, Sendable {
    case context
    case insertion
    case deletion
}

public struct DiffLine: Equatable, Sendable, Identifiable {
    public var id: Int
    public var kind: DiffLineKind
    public var text: String

    public init(id: Int, kind: DiffLineKind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }

    public var prefix: String {
        switch kind {
        case .context: return " "
        case .insertion: return "+"
        case .deletion: return "-"
        }
    }
}

/// Compact line-oriented diff for review overlays (Phase 5).
public enum TextDiff {
    public static func lines(before: String, after: String) -> [DiffLine] {
        let left = before.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let right = after.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if left == right {
            return left.enumerated().map { DiffLine(id: $0.offset, kind: .context, text: $0.element) }
        }

        var result: [DiffLine] = []
        var id = 0
        var i = 0
        var j = 0
        while i < left.count || j < right.count {
            if i < left.count, j < right.count, left[i] == right[j] {
                result.append(DiffLine(id: id, kind: .context, text: left[i]))
                id += 1
                i += 1
                j += 1
                continue
            }
            if j < right.count, (i >= left.count || right[j...].contains(left[i]) == false) {
                result.append(DiffLine(id: id, kind: .insertion, text: right[j]))
                id += 1
                j += 1
                continue
            }
            if i < left.count {
                result.append(DiffLine(id: id, kind: .deletion, text: left[i]))
                id += 1
                i += 1
                continue
            }
            if j < right.count {
                result.append(DiffLine(id: id, kind: .insertion, text: right[j]))
                id += 1
                j += 1
            }
        }
        return result
    }

    public static func unified(before: String, after: String) -> String {
        lines(before: before, after: after)
            .map { "\($0.prefix)\($0.text)" }
            .joined(separator: "\n")
    }
}
