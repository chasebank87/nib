import Foundation

public enum DocumentError: Error, Equatable, Sendable {
    case invalidUTF8
    case unsupportedEncoding(String)
    case encodingFailed
    case emptyTypeName

    public var localizedDescription: String {
        switch self {
        case .invalidUTF8:
            "This file is not valid UTF-8. nib will not guess an encoding and risk corrupting it."
        case .unsupportedEncoding(let name):
            "The encoding “\(name)” is not supported in this version. Convert the file to UTF-8 and try again."
        case .encodingFailed:
            "The document could not be encoded as UTF-8."
        case .emptyTypeName:
            "The document type was missing."
        }
    }
}
