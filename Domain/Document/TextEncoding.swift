import Foundation

public enum TextEncoding: String, Equatable, Sendable, CaseIterable, Codable {
    case utf8
    case utf8WithBOM

    public var displayName: String {
        switch self {
        case .utf8:
            "UTF-8"
        case .utf8WithBOM:
            "UTF-8 with BOM"
        }
    }

    public var hasBOM: Bool {
        self == .utf8WithBOM
    }
}

public enum EncodingSniff {
    public static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
    public static let utf16LEBOM: [UInt8] = [0xFF, 0xFE]
    public static let utf16BEBOM: [UInt8] = [0xFE, 0xFF]

    /// Detects encoding. Only UTF-8 (optional BOM) is accepted. UTF-16 is refused
    /// so we never silently reinterpret bytes.
    public static func detect(_ data: Data) throws -> TextEncoding {
        if data.starts(with: utf16LEBOM) {
            throw DocumentError.unsupportedEncoding("UTF-16 LE")
        }
        if data.starts(with: utf16BEBOM) {
            throw DocumentError.unsupportedEncoding("UTF-16 BE")
        }
        if data.starts(with: utf8BOM) {
            return .utf8WithBOM
        }
        return .utf8
    }

    public static func payload(strippingBOMFrom data: Data, encoding: TextEncoding) -> Data {
        if encoding.hasBOM, data.count >= 3 {
            return data.dropFirst(3)
        }
        return data
    }
}
