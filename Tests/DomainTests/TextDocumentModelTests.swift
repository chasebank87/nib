import Foundation
import NibDomain
import NibServices
import Testing

struct TextDocumentModelTests {
    private let codec = UTF8DocumentCodec()

    @Test func startsCleanAndEmpty() {
        let model = TextDocumentModel()
        #expect(model.text.isEmpty)
        #expect(model.isDirty == false)
        #expect(model.encoding == .utf8)
        #expect(model.lineEnding == .lf)
    }

    @Test func replaceTextMarksDirty() {
        var model = TextDocumentModel(text: "hello")
        model.replaceText("hello")
        #expect(model.isDirty == false)
        model.replaceText("hello, nib")
        #expect(model.text == "hello, nib")
        #expect(model.isDirty)
        model.markSaved()
        #expect(model.isDirty == false)
    }

    @Test func decodeUTF8NormalizesCRLFAndPreservesOnEncode() throws {
        let original = "one\r\ntwo\r\nthree\r\n"
        let model = try codec.decode(Data(original.utf8))
        #expect(model.lineEnding == .crlf)
        #expect(model.text == "one\ntwo\nthree\n")
        #expect(model.isDirty == false)
        let encoded = try codec.encode(model)
        #expect(String(data: encoded, encoding: .utf8) == original)
    }

    @Test func decodePreservesLF() throws {
        let original = "alpha\nbeta\n"
        let model = try codec.decode(Data(original.utf8))
        #expect(model.lineEnding == .lf)
        #expect(try codec.encode(model) == Data(original.utf8))
    }

    @Test func decodePreservesCR() throws {
        let original = "alpha\rbeta\r"
        let model = try codec.decode(Data(original.utf8))
        #expect(model.lineEnding == .cr)
        #expect(try String(data: codec.encode(model), encoding: .utf8) == original)
    }

    @Test func decodeEmptyFile() throws {
        let model = try codec.decode(Data())
        #expect(model.text.isEmpty)
        #expect(model.lineEnding == .lf)
    }

    @Test func decodeRejectsInvalidUTF8() {
        let invalid = Data([0x80])
        #expect(throws: DocumentError.invalidUTF8) {
            try codec.decode(invalid)
        }
    }

    @Test func detectLineEndingTiesPreferCRLF() {
        #expect(LineEnding.detect(in: "a\r\nb\nc") == .crlf)
        #expect(LineEnding.detect(in: "") == .lf)
    }

    @Test func commandFilterFuzzyAndLiteral() {
        let command = EditorCommand(
            id: BuiltInCommandID.toggleAppearance,
            title: "Toggle Appearance",
            keywords: ["theme"]
        )
        #expect(CommandFilter.matches(command, query: ""))
        #expect(CommandFilter.matches(command, query: "app"))
        #expect(CommandFilter.matches(command, query: "tapp"))
        #expect(CommandFilter.matches(command, query: "theme"))
        #expect(CommandFilter.matches(command, query: "xyz") == false)
    }
}
