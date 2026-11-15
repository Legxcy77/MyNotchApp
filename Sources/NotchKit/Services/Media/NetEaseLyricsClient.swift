import Foundation

public struct NetEaseLyricsClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchLyrics(
        artist: String,
        track: String,
        duration: TimeInterval? = nil
    ) async throws -> LRCDocument? {
        let query = "\(track) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              var searchComponents = URLComponents(string: "https://music.163.com/api/search/get") else {
            return nil
        }
        searchComponents.queryItems = [
            URLQueryItem(name: "s", value: query),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let searchURL = searchComponents.url else { return nil }

        var searchReq = URLRequest(url: searchURL)
        searchReq.timeoutInterval = 6
        searchReq.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        searchReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (searchData, searchResp) = try await session.data(for: searchReq)
        guard let httpSearch = searchResp as? HTTPURLResponse,
              (200..<300).contains(httpSearch.statusCode) else {
            return nil
        }

        let searchDecoded = try JSONDecoder().decode(NetEaseSearchResponse.self, from: searchData)
        guard let songs = searchDecoded.result?.songs, !songs.isEmpty else {
            return nil
        }

        let matchedSong = bestMatch(songs: songs, targetTrack: track, targetDuration: duration)
        guard let song = matchedSong else { return nil }

        var lyricComponents = URLComponents(string: "https://music.163.com/api/song/lyric")
        lyricComponents?.queryItems = [
            URLQueryItem(name: "id", value: String(song.id)),
            URLQueryItem(name: "lv", value: "1"),
            URLQueryItem(name: "kv", value: "1"),
            URLQueryItem(name: "tv", value: "-1"),
        ]
        guard let lyricURL = lyricComponents?.url else { return nil }

        var lyricReq = URLRequest(url: lyricURL)
        lyricReq.timeoutInterval = 6
        lyricReq.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        lyricReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (lyricData, lyricResp) = try await session.data(for: lyricReq)
        guard let httpLyric = lyricResp as? HTTPURLResponse,
              (200..<300).contains(httpLyric.statusCode) else {
            return nil
        }

        let lyricDecoded = try JSONDecoder().decode(NetEaseLyricResponse.self, from: lyricData)
        let rawLRC = lyricDecoded.lrc?.lyric ?? lyricDecoded.klyric?.lyric
        guard let rawLRC, !rawLRC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let parsed = LRCParser.parse(rawLRC)
        if !parsed.lines.isEmpty {
            return LRCDocument(
                title: parsed.title ?? song.name,
                artist: parsed.artist ?? song.artists?.first?.name ?? artist,
                album: parsed.album,
                offset: parsed.offset,
                lines: parsed.lines,
                isSynced: true,
                sourceLabel: "NetEase"
            )
        }
        return LRCParser.plain(
            rawLRC,
            title: song.name,
            artist: song.artists?.first?.name ?? artist,
            sourceLabel: "NetEase"
        )
    }

    private func bestMatch(
        songs: [NetEaseSong],
        targetTrack: String,
        targetDuration: TimeInterval?
    ) -> NetEaseSong? {
        let normalizedTrack = targetTrack.lowercased()
        if let targetDuration, targetDuration > 0 {
            let durationMatches = songs.filter { song in
                let sec = TimeInterval(song.duration ?? 0) / 1000.0
                return sec <= 0 || abs(sec - targetDuration) <= 4.0
            }
            if let exact = durationMatches.first(where: { $0.name.lowercased().contains(normalizedTrack) }) {
                return exact
            }
            return durationMatches.first
        }
        return songs.first(where: { $0.name.lowercased().contains(normalizedTrack) }) ?? songs.first
    }
}

private struct NetEaseSearchResponse: Decodable {
    let result: NetEaseSearchResult?
}

private struct NetEaseSearchResult: Decodable {
    let songs: [NetEaseSong]?
}

private struct NetEaseSong: Decodable {
    let id: Int
    let name: String
    let duration: Int?
    let artists: [NetEaseArtist]?
}

private struct NetEaseArtist: Decodable {
    let name: String
}

private struct NetEaseLyricResponse: Decodable {
    let lrc: NetEaseLyricBody?
    let klyric: NetEaseLyricBody?
}

private struct NetEaseLyricBody: Decodable {
    let lyric: String?
}

