import Foundation
import Security

public struct FaceProfile: Codable, Equatable, Sendable {
    public let embeddings: [[Float]]
    public let enrolledAt: Date

    public init(embeddings: [[Float]], enrolledAt: Date = .now) {
        self.embeddings = embeddings
        self.enrolledAt = enrolledAt
    }
}

public enum FaceProfileStore {
    private static let service = "com.pawalit.MyNotchApp.faceprofile"
    private static let account = "owner"

    public static var hasEnrolledFace: Bool {
        load() != nil
    }

    @discardableResult
    public static func save(_ profile: FaceProfile) -> Bool {
        guard let data = try? JSONEncoder().encode(profile) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func load() -> FaceProfile? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(FaceProfile.self, from: data)
    }

    @discardableResult
    public static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

