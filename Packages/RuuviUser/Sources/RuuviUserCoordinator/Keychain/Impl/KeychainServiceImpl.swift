#if SWIFT_PACKAGE
    import RuuviUser
#endif
import Foundation
import Security

/// Uses the same service, access group, account names and protection class as existing installations.
final class KeychainServiceImpl: KeychainService {
    private let service: String
    private let accessGroup: String?
    private let client: KeychainClient

    init(
        service: String = "com.ruuvi.station",
        accessGroup: String? = "4MUYJ4YYH4.com.ruuvi.station",
        client: KeychainClient = .system
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.client = client
    }

    var ruuviUserApiKey: String? {
        get { read(account: "ruuviUserApi") }
        set { write(newValue, account: "ruuviUserApi") }
    }

    var userApiEmail: String? {
        get { read(account: "userApiEmail") }
        set { write(newValue, account: "userApiEmail") }
    }

    var userIsAuthorized: Bool { ruuviUserApiKey?.isEmpty == false }

    private func query(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    private func read(account: String) -> String? {
        var query = query(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        let (status, result) = client.copyMatching(query)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String?, account: String) {
        let query = query(account: account)
        guard let value else {
            _ = client.delete(query)
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrLabel as String: "Ruuvi Station",
            kSecAttrSynchronizable as String: false,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = client.update(query, attributes)
        guard status == errSecItemNotFound else { return }
        let item = query.merging(attributes) { _, new in new }
        if client.add(item) == errSecDuplicateItem {
            // Another process (for example a widget) may have inserted the item after our update.
            _ = client.update(query, attributes)
        }
    }
}

struct KeychainClient {
    var copyMatching: ([String: Any]) -> (OSStatus, AnyObject?)
    var update: ([String: Any], [String: Any]) -> OSStatus
    var add: ([String: Any]) -> OSStatus
    var delete: ([String: Any]) -> OSStatus

    static let system = KeychainClient(
        copyMatching: { query in
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result)
        },
        update: { SecItemUpdate($0 as CFDictionary, $1 as CFDictionary) },
        add: { SecItemAdd($0 as CFDictionary, nil) },
        delete: { SecItemDelete($0 as CFDictionary) })
}
