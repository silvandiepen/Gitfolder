import Foundation
import Security

/// Stores a secret (e.g. a GitHub token) in the keychain. Generalised from
/// GitFolder's `KeychainService` so both apps share it — `service` and `account`
/// are configurable, so GitFolder and GitKanban can keep separate items.
public struct KeychainService: Sendable {
    private let service: String
    private let account: String

    public init(service: String, account: String = "github-token") {
        self.service = service
        self.account = account
    }

    /// Save the secret. An empty/whitespace value deletes the item instead.
    public func save(_ secret: String) throws {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try delete()
            return
        }

        let data = Data(trimmed.utf8)
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound {
            throw KeychainError.unhandledStatus(status)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandledStatus(addStatus)
        }
    }

    public func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public enum KeychainError: LocalizedError, Equatable, Sendable {
    case invalidData
    case unhandledStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The stored secret could not be read."
        case let .unhandledStatus(status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
