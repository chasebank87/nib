import NibDomain
import Testing

struct LineColumnTests {
    @Test func parseLineAndColumn() {
        #expect(LineColumnParser.parse("12") == LineColumn(line: 12, column: 1))
        #expect(LineColumnParser.parse(" 12:4 ") == LineColumn(line: 12, column: 4))
        #expect(LineColumnParser.parse("12,4") == LineColumn(line: 12, column: 4))
        #expect(LineColumnParser.parse("") == nil)
        #expect(LineColumnParser.parse("0") == nil)
        #expect(LineColumnParser.parse("ab") == nil)
    }

    @Test func clampAndUTF16Offset() {
        let text = "ab\ncafé\n"
        let clamped = LineColumnParser.clamp(LineColumn(line: 99, column: 99), in: text)
        #expect(clamped.line == 3)
        #expect(clamped.column == 1)
        #expect(LineColumnParser.utf16Offset(of: LineColumn(line: 1, column: 1), in: text) == 0)
        #expect(LineColumnParser.utf16Offset(of: LineColumn(line: 2, column: 1), in: text) == 3)
        #expect(LineColumnParser.lineCount(in: "") == 1)
        #expect(LineColumnParser.lineCount(in: text) == 3)
    }

    @Test func emptyDocumentIsLineOne() {
        let target = LineColumnParser.clamp(LineColumn(line: 1, column: 1), in: "")
        #expect(target == LineColumn(line: 1, column: 1))
        #expect(LineColumnParser.utf16Offset(of: target, in: "") == 0)
    }
}
