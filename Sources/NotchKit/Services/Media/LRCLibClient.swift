import Foundation

public struct LRCLibResponse: Codable, Equatable, Sendable {
    public let id: Int?
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?

    public init(
        id: Int? = nil,
        trackName: String? = nil,
        artistName: String? = nil,
        albumName: String? = nil,
        duration: Double? = nil,
        instrumental: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }
}

public enum LRCLibError: Error, Equatable, Sendable {
    case invalidURL
    case notFound
    case httpError(Int)
    case networkError(String)
}

public enum LRCLibQueryCleaner {
    private static let noisePatterns: [String] = [
        #"\s*\|\s*(TikTok|YouTube)\s*$"#,
        #"\s*-\s*YouTube\s*$"#,
        #"\s*[\(\[]\s*(Official\s*(Music\s*)?(Video|Audio|Lyric\s*Video)|Color\s*Coded\s*Lyrics|Performance\s*Film|Visualizer|Lyric\s*Video|Lyrics?|Audio|M/?V|HD|4K|가사|日本語字幕|歌詞)\s*[\)\]]"#,
        #"\s*[\(\[]\s*(feat\.?|ft\.?)\s+[^\)\]]+[\)\]]"#,
    ]

    private static let nativeScriptPattern = #"[\u0E00-\u0E7F\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF\u0400-\u04FF\u0600-\u06FF]"#

    public static func clean(artist: String, track: String) -> (artist: String, track: String, searchQuery: String) {
        var cleanedTrack = track.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(cleanedTrack.startIndex..<cleanedTrack.endIndex, in: cleanedTrack)
                cleanedTrack = regex.stringByReplacingMatches(in: cleanedTrack, range: range, withTemplate: "")
            }
        }
        cleanedTrack = cleanedTrack
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        // Localized artist joiners (Thai, Japanese, Chinese)
        cleanedArtist = cleanedArtist
            .replacingOccurrences(of: "และ", with: " & ")
            .replacingOccurrences(of: "กับ", with: " & ")
            .replacingOccurrences(of: "・", with: " & ")
            .replacingOccurrences(of: "、", with: " & ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let dashRange = cleanedTrack.range(of: " - ") {
            let left = String(cleanedTrack[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(cleanedTrack[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty, !right.isEmpty {
                cleanedArtist = left
                cleanedTrack = right
            }
        }

        let trimmedQuotes = cleanedTrack.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        if !trimmedQuotes.isEmpty {
            cleanedTrack = trimmedQuotes
        }

        let primaryArtist = cleanedArtist
            .components(separatedBy: CharacterSet(charactersIn: "&,"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? cleanedArtist
        let searchArtist = primaryArtist.isEmpty ? cleanedArtist : primaryArtist
        let query = searchArtist.isEmpty ? cleanedTrack : "\(searchArtist) \(cleanedTrack)"
        return (cleanedArtist, cleanedTrack, query)
    }

    public static func pickBestMatch(
        from candidates: [LRCLibResponse],
        targetDuration: TimeInterval?
    ) -> LRCLibResponse? {
        let withLyrics = candidates.filter {
            ($0.syncedLyrics ?? "").isEmpty == false || ($0.plainLyrics ?? "").isEmpty == false
        }
        guard !withLyrics.isEmpty else { return nil }

        let durationMatched: [LRCLibResponse]
        if let targetDuration, targetDuration > 0 {
            let matching = withLyrics.filter { item in
                guard let d = item.duration else { return false }
                return abs(d - targetDuration) <= 4.0
            }
            guard !matching.isEmpty else { return nil }
            durationMatched = matching
        } else {
            durationMatched = withLyrics
        }

        let synced = durationMatched.filter { ($0.syncedLyrics ?? "").isEmpty == false }
        let pool = synced.isEmpty ? durationMatched : synced

        // Prefer native non-Latin scripts (Thai, Korean, Japanese, Chinese, Cyrillic, Arabic) over romanized karaoke
        if let nativeMatch = pool.first(where: {
            let text = ($0.syncedLyrics ?? "") + ($0.plainLyrics ?? "")
            return text.range(of: nativeScriptPattern, options: .regularExpression) != nil
        }) {
            return nativeMatch
        }
        return pool.first
    }
}

public struct LRCLibClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchLyrics(
        artist: String,
        track: String,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLibResponse {
        let cleaned = LRCLibQueryCleaner.clean(artist: artist, track: track)
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "artist_name", value: cleaned.artist),
            URLQueryItem(name: "track_name", value: cleaned.track),
        ]
        if let album, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw LRCLibError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("MyNotchApp/1.0 (https://github.com/pawalit/MyNotchApp)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LRCLibError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LRCLibError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(LRCLibResponse.self, from: data)
        case 404:
            if let fallback = try await searchFallback(query: cleaned.searchQuery, duration: duration) {
                return fallback
            }
            if cleaned.searchQuery != cleaned.track,
               let trackOnly = try await searchFallback(query: cleaned.track, duration: duration) {
                return trackOnly
            }
            throw LRCLibError.notFound
        default:
            throw LRCLibError.httpError(http.statusCode)
        }
    }

    private func searchFallback(query: String, duration: TimeInterval?) async throws -> LRCLibResponse? {
        guard !query.isEmpty,
              var components = URLComponents(string: "https://lrclib.net/api/search") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("MyNotchApp/1.0 (https://github.com/pawalit/MyNotchApp)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        let candidates = (try? JSONDecoder().decode([LRCLibResponse].self, from: data)) ?? []
        return LRCLibQueryCleaner.pickBestMatch(from: candidates, targetDuration: duration)
    }
}

