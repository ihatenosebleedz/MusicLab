import Foundation
#if canImport(Security)
import Security
#endif

public final class KeychainService: @unchecked Sendable {
    private let service: String
    private let account: String
    
    public init(service: String = "com.musiclab.app", account: String = "bearerToken") {
        self.service = service
        self.account = account
    }
    
    public func save(_ token: String) {
#if canImport(Security)
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
#else
        UserDefaults.standard.set(token, forKey: "MusicLab.Keychain.BearerToken")
#endif
    }
    
    public func load() -> String? {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
#else
        return UserDefaults.standard.string(forKey: "MusicLab.Keychain.BearerToken")
#endif
    }
    
    public func delete() {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
#else
        UserDefaults.standard.removeObject(forKey: "MusicLab.Keychain.BearerToken")
#endif
    }
}
