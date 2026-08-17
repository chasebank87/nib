import Foundation

public struct DocumentRecoveryPayload: Codable, Equatable, Sendable {
    public var id: UUID
    public var filePath: String?
    public var text: String
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var isMixedLineEndings: Bool
    public var updatedAt: Date

    public init(
        id: UUID,
        filePath: String?,
        text: String,
        encoding: TextEncoding,
        lineEnding: LineEnding,
        isMixedLineEndings: Bool,
        updatedAt: Date
    ) {
        self.id = id
        self.filePath = filePath
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isMixedLineEndings = isMixedLineEndings
        self.updatedAt = updatedAt
    }
}

public protocol DocumentRecoveryStoring: AnyObject {
    func save(_ payload: DocumentRecoveryPayload) throws
    func loadAll() throws -> [DocumentRecoveryPayload]
    func remove(id: UUID) throws
    func removeAll() throws
}
