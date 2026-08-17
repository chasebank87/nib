import Foundation
import NibDomain

/// Test double. Production Keychain store is NIB-014.
public final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private var secrets: [String: Data] = [:]

    public init() {}

    public func store(account: String, secret: Data) throws {
        secrets[account] = secret
    }

    public func retrieve(account: String) throws -> Data? {
        secrets[account]
    }

    public func delete(account: String) throws {
        secrets.removeValue(forKey: account)
    }
}
