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
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track),
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
            throw LRCLibError.notFound
        default:
            throw LRCLibError.httpError(http.statusCode)
        }
    }
}
