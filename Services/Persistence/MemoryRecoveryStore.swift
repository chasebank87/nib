import Foundation
import NibDomain

public final class MemoryRecoveryStore: DocumentRecoveryStoring, @unchecked Sendable {
    private var payloads: [UUID: DocumentRecoveryPayload] = [:]

    public init(payloads: [DocumentRecoveryPayload] = []) {
        for payload in payloads {
            self.payloads[payload.id] = payload
        }
    }

    public func save(_ payload: DocumentRecoveryPayload) throws {
        payloads[payload.id] = payload
    }

    public func loadAll() throws -> [DocumentRecoveryPayload] {
        payloads.values.sorted { $0.updatedAt < $1.updatedAt }
    }

    public func remove(id: UUID) throws {
        payloads.removeValue(forKey: id)
    }

    public func removeAll() throws {
        payloads.removeAll()
    }
}
