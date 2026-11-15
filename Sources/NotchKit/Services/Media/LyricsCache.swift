import CryptoKit
import Foundation

public actor LyricsCache {
    private let directory: URL
    private var memory: [String: LRCLibResponse] = [:]
    private var offsets: [String: TimeInterval] = [:]
    private var offsetsLoaded = false

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches", isDirectory: true)
            self.directory = caches.appendingPathComponent("MyNotchApp/lyrics", isDirectory: true)
        }
    }

    public func lyrics(
        artist: String,
        track: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        using client: LRCLibClient
    ) async throws -> LRCLibResponse? {
        let key = cacheKey(artist: artist, track: track, album: album)
        if let cached = memory[key] {
            return cached
        }

        let fileURL = directory.appendingPathComponent("\(key).json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(LRCLibResponse.self, from: data) {
            memory[key] = decoded
            return decoded
        }

        do {
            let fetched = try await client.fetchLyrics(
                artist: artist,
                track: track,
                album: album,
                duration: duration
            )
            memory[key] = fetched
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let encoded = try? JSONEncoder().encode(fetched) {
                try? encoded.write(to: fileURL, options: .atomic)
            }
            return fetched
        } catch LRCLibError.notFound {
            return nil
        }
    }

    private func cacheKey(artist: String, track: String, album: String?) -> String {
        let raw = "\(artist.lowercased().trimmingCharacters(in: .whitespaces))|\(track.lowercased().trimmingCharacters(in: .whitespaces))|\((album ?? "").lowercased().trimmingCharacters(in: .whitespaces))"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func savedOffset(for trackKey: String) -> TimeInterval {
        loadOffsetsIfNeeded()
        return offsets[trackKey] ?? 0
    }

    public func saveOffset(_ offset: TimeInterval, for trackKey: String) {
        loadOffsetsIfNeeded()
        offsets[trackKey] = offset
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("offsets.json")
        if let data = try? JSONEncoder().encode(offsets) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadOffsetsIfNeeded() {
        guard !offsetsLoaded else { return }
        offsetsLoaded = true
        let url = directory.appendingPathComponent("offsets.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            offsets = decoded
        }
    }
}

