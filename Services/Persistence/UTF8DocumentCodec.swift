import Foundation
import NibCoreBridge
import NibDomain

public struct UTF8DocumentCodec: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> TextDocumentModel {
        let encoding = try EncodingSniff.detect(data)
        let payload = EncodingSniff.payload(strippingBOMFrom: data, encoding: encoding)
        try NibCore.validateUTF8(payload)
        guard let raw = String(data: payload, encoding: .utf8) else {
            throw DocumentError.invalidUTF8
        }
        let scan = LineEnding.scan(in: raw)
        let normalized = LineEnding.normalizeToLF(raw)
        return TextDocumentModel(
            text: normalized,
            encoding: encoding,
            lineEnding: scan.ending,
            isDirty: false,
            isMixedLineEndings: scan.isMixed,
            originalBytes: data,
            byteCount: data.count,
            isReducedFeature: DocumentLimits.isReducedFeature(data.count)
        )
    }

    public func encode(_ model: TextDocumentModel) throws -> Data {
        if model.isDirty == false, let original = model.originalBytes {
            return original
        }
        let body = model.text.replacingOccurrences(of: "\n", with: model.lineEnding.sequence)
        guard var data = body.data(using: .utf8) else {
            throw DocumentError.encodingFailed
        }
        if model.encoding.hasBOM {
            data = Data(EncodingSniff.utf8BOM) + data
        }
        return data
    }
}
