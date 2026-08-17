import Foundation
import NibDomain

/// Applies LSP `TextEdit`s to a UTF-16 string buffer (bottom-up so offsets stay valid).
public enum TextEditApplier {
    public static func apply(_ edits: [TextEdit], to text: String) throws -> String {
        guard edits.isEmpty == false else { return text }
        let sorted = edits.sorted { lhs, rhs in
            if lhs.start.line != rhs.start.line {
                return lhs.start.line > rhs.start.line
            }
            if lhs.start.character != rhs.start.character {
                return lhs.start.character > rhs.start.character
            }
            if lhs.end.line != rhs.end.line {
                return lhs.end.line > rhs.end.line
            }
            return lhs.end.character > rhs.end.character
        }
        var result = text
        for edit in sorted {
            let lower = LineColumnParser.utf16Offset(
                lspLine: edit.start.line,
                lspCharacter: edit.start.character,
                in: result
            )
            let upper = LineColumnParser.utf16Offset(
                lspLine: edit.end.line,
                lspCharacter: edit.end.character,
                in: result
            )
            let range = min(lower, upper)..<max(lower, upper)
            result = try TextPatchApplier.replaceUTF16Range(in: result, range: range, with: edit.newText)
        }
        return result
    }
}
