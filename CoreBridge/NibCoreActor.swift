import Foundation

/// Serializes Zig core calls. The C ABI is not documented as thread-safe in this slice.
public actor NibCoreActor {
    public init() {}

    public func version() -> String {
        NibCore.version
    }

    public func isValidUTF8(_ data: Data) -> Bool {
        NibCore.isValidUTF8(data)
    }

    public func validateUTF8(_ data: Data) throws {
        try NibCore.validateUTF8(data)
    }
}
