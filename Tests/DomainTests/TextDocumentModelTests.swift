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

    @Test func replaceTextMarksDirtyAndDropsOriginalBytes() {
        var model = TextDocumentModel(text: "hello", originalBytes: Data("hello".utf8))
        model.replaceText("hello")
        #expect(model.isDirty == false)
        model.replaceText("hello, nib")
        #expect(model.text == "hello, nib")
        #expect(model.isDirty)
        #expect(model.originalBytes == nil)
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

    @Test func mixedEndingsPreserveOriginalBytesUntilEdit() throws {
        let original = "a\r\nb\nc\r"
        let data = Data(original.utf8)
        var model = try codec.decode(data)
        #expect(model.isMixedLineEndings)
        #expect(model.lineEnding == .crlf)
        #expect(try codec.encode(model) == data)

        model.replaceText("a\nb\nc\n")
        let encoded = try codec.encode(model)
        #expect(String(data: encoded, encoding: .utf8) == "a\r\nb\r\nc\r\n")
    }

    @Test func utf8BOMIsPreserved() throws {
        var data = Data(EncodingSniff.utf8BOM)
        data.append(contentsOf: "hi\n".utf8)
        let model = try codec.decode(data)
        #expect(model.encoding == .utf8WithBOM)
        #expect(model.text == "hi\n")
        #expect(try codec.encode(model) == data)
    }

    @Test func utf16BOMIsRefused() {
        #expect(throws: DocumentError.unsupportedEncoding("UTF-16 LE")) {
            try codec.decode(Data(EncodingSniff.utf16LEBOM + [0x68, 0x00]))
        }
        #expect(throws: DocumentError.unsupportedEncoding("UTF-16 BE")) {
            try codec.decode(Data(EncodingSniff.utf16BEBOM + [0x00, 0x68]))
        }
    }

    @Test func decodeEmptyFile() throws {
        let model = try codec.decode(Data())
        #expect(model.text.isEmpty)
        #expect(model.lineEnding == .lf)
        #expect(model.encoding == .utf8)
    }

    @Test func decodeRejectsInvalidUTF8() {
        let invalid = Data([0x80])
        #expect(throws: DocumentError.invalidUTF8) {
            try codec.decode(invalid)
        }
    }

    @Test func detectLineEndingTiesPreferCRLF() {
        #expect(LineEnding.detect(in: "a\r\nb\nc") == .crlf)
        #expect(LineEnding.scan(in: "a\r\nb\nc").isMixed)
        #expect(LineEnding.detect(in: "") == .lf)
    }

    @Test func reducedFeatureThresholds() {
        #expect(DocumentLimits.isReducedFeature(DocumentLimits.reducedFeatureByteCount))
        #expect(DocumentLimits.isReducedFeature(DocumentLimits.reducedFeatureByteCount - 1) == false)
        #expect(DocumentLimits.needsOpenWarning(DocumentLimits.hardWarningByteCount))
    }
}
