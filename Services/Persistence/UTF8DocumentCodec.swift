import Foundation
import NibCoreBridge
import NibDomain

public struct UTF8DocumentCodec: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> TextDocumentModel {
        try NibCore.validateUTF8(data)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidUTF8
        }
        let ending = LineEnding.detect(in: raw)
        let normalized = LineEnding.normalizeToLF(raw)
        return TextDocumentModel(
            text: normalized,
            encoding: .utf8,
            lineEnding: ending,
            isDirty: false
        )
    }

    public func encode(_ model: TextDocumentModel) throws -> Data {
        let body = model.text.replacingOccurrences(of: "\n", with: model.lineEnding.sequence)
        guard let data = body.data(using: .utf8) else {
            throw DocumentError.encodingFailed
        }
        return data
    }
}
