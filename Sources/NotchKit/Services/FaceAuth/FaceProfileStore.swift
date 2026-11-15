import Foundation

public struct FaceProfile: Codable, Equatable, Sendable {
    public let embeddings: [[Float]]
    public let enrolledAt: Date

    public init(embeddings: [[Float]], enrolledAt: Date = .now) {
        self.embeddings = embeddings
        self.enrolledAt = enrolledAt
    }
}

public enum FaceProfileStore {
    private static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mynotch", isDirectory: true)
    }

    private static var defaultFileURL: URL {
        defaultDirectory.appendingPathComponent("face_profile.json")
    }

    public static var hasEnrolledFace: Bool {
        FileManager.default.fileExists(atPath: defaultFileURL.path)
    }

    @discardableResult
    public static func save(_ profile: FaceProfile, to url: URL? = nil) -> Bool {
        let targetURL = url ?? defaultFileURL
        let dirURL = targetURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(profile)
            try data.write(to: targetURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: targetURL.path
            )
            return true
        } catch {
            return false
        }
    }

    public static func load(from url: URL? = nil) -> FaceProfile? {
        let targetURL = url ?? defaultFileURL
        guard let data = try? Data(contentsOf: targetURL) else {
            return nil
        }
        return try? JSONDecoder().decode(FaceProfile.self, from: data)
    }

    @discardableResult
    public static func delete(at url: URL? = nil) -> Bool {
        let targetURL = url ?? defaultFileURL
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return true
        }
        do {
            try FileManager.default.removeItem(at: targetURL)
            return true
        } catch {
            return false
        }
    }
}
