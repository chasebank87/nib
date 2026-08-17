import Foundation
import NibDomain
import Security

/// Keychain-backed `SecretStoring` (NIB-014). Service: `com.chaseelder.nib`.
public struct KeychainSecretStore: SecretStoring, Sendable {
    public static let service = "com.chaseelder.nib"
    public static let providerAPIKeyAccount = "ai.provider.apiKey"

    public init() {}

    public func store(account: String, secret: Data) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretStoreError.keychain(status)
        }
    }

    public func retrieve(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecretStoreError.keychain(status)
        }
        return item as? Data
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw SecretStoreError.keychain(status)
    }
}

public enum SecretStoreError: Error, Equatable, Sendable {
    case keychain(OSStatus)
}
