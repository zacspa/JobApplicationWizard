import Foundation
import Security
import ComposableArchitecture

private let service = "com.zsparks.jobapplicationwizard"
private let account = "claude-api-key"

public struct KeychainClient {
    public var loadAPIKey: @Sendable () -> String
    public var saveAPIKey: @Sendable (String) -> Void

    public init(
        loadAPIKey: @escaping @Sendable () -> String,
        saveAPIKey: @escaping @Sendable (String) -> Void
    ) {
        self.loadAPIKey = loadAPIKey
        self.saveAPIKey = saveAPIKey
    }
}

extension KeychainClient: DependencyKey {
    public static var liveValue: KeychainClient {
        KeychainClient(
            loadAPIKey: {
                let query: [CFString: Any] = [
                    kSecClass:           kSecClassGenericPassword,
                    kSecAttrService:     service,
                    kSecAttrAccount:     account,
                    kSecReturnData:      true,
                    kSecMatchLimit:      kSecMatchLimitOne
                ]
                var result: CFTypeRef?
                guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                      let data = result as? Data,
                      let key = String(data: data, encoding: .utf8)
                else { return "" }
                return key
            },
            saveAPIKey: { key in
                let data = Data(key.utf8)
                let query: [CFString: Any] = [
                    kSecClass:       kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: account
                ]
                if key.isEmpty {
                    SecItemDelete(query as CFDictionary)
                    return
                }
                let attributes: [CFString: Any] = [kSecValueData: data]
                if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
                    var addQuery = query
                    addQuery[kSecValueData] = data
                    SecItemAdd(addQuery as CFDictionary, nil)
                }
            }
        )
    }
}

extension KeychainClient: TestDependencyKey {
    public static let testValue = KeychainClient(
        loadAPIKey: unimplemented("\(Self.self).loadAPIKey", placeholder: ""),
        saveAPIKey: unimplemented("\(Self.self).saveAPIKey", placeholder: ())
    )
}

extension DependencyValues {
    public var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}
