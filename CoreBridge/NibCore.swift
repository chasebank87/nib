import Foundation
import NibDomain

public enum NibCore {
    public static var version: String {
        String(cString: nib_core_version())
    }

    public static func isValidUTF8(_ data: Data) -> Bool {
        if data.isEmpty { return true }
        return data.withUnsafeBytes { buffer in
            let pointer = buffer.bindMemory(to: UInt8.self).baseAddress
            return nib_core_utf8_validate(pointer, buffer.count) == 1
        }
    }

    public static func validateUTF8(_ data: Data) throws {
        guard isValidUTF8(data) else {
            throw DocumentError.invalidUTF8
        }
    }
}
