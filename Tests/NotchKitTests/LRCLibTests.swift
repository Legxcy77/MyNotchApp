import Foundation
import Testing
@testable import NotchKit

// URLProtocol is instantiated by Foundation with no instance-injection hook; tests run `.serialized`.
private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct LRCLibTests {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func tempCacheDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchKitLyricsTest-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func fetches200AndCachesSecondHitInMemoryAndDisk() async throws {
        MockURLProtocol.requestCount = 0
        MockURLProtocol.handler = { req in
            let url = req.url!
            let res = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"{"id":1,"trackName":"Midnight City","artistName":"M83","syncedLyrics":"[00:05.00]Waiting"}"#
            return (res, Data(json.utf8))
        }

        let dir = tempCacheDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let client = LRCLibClient(session: makeSession())
        let cache = LyricsCache(directory: dir)

        let first = try await cache.lyrics(artist: "M83", track: "Midnight City", album: "Hurry Up", duration: 243, using: client)
        #expect(first?.syncedLyrics == "[00:05.00]Waiting")
        #expect(MockURLProtocol.requestCount == 1)

        // Second hit comes from memory cache (no network request)
        let second = try await cache.lyrics(artist: "M83", track: "Midnight City", album: "Hurry Up", duration: 243, using: client)
        #expect(second?.syncedLyrics == "[00:05.00]Waiting")
        #expect(MockURLProtocol.requestCount == 1)

        // Fresh LyricsCache instance reads from disk cache (still no network request)
        let diskCache = LyricsCache(directory: dir)
        let third = try await diskCache.lyrics(artist: "M83", track: "Midnight City", album: "Hurry Up", duration: 243, using: client)
        #expect(third?.syncedLyrics == "[00:05.00]Waiting")
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test func returnsNilOn404AndThrowsOnTimeout() async throws {
        let dir = tempCacheDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let client = LRCLibClient(session: makeSession())
        let cache = LyricsCache(directory: dir)

        // 404 -> nil
        MockURLProtocol.requestCount = 0
        MockURLProtocol.handler = { req in
            let res = HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (res, Data())
        }
        let missing = try await cache.lyrics(artist: "Unknown", track: "Missing", using: client)
        #expect(missing == nil)

        // Timeout -> throws
        MockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }
        var didThrowTimeout = false
        do {
            _ = try await cache.lyrics(artist: "Slow", track: "Track", using: client)
        } catch {
            didThrowTimeout = true
        }
        #expect(didThrowTimeout)
    }

    @Test func cleansYouTubeTitlesAndRejectsMismatchedDuration() {
        let cleaned = LRCLibQueryCleaner.clean(
            artist: "Channel",
            track: "B.I - BTBT (Official Video) | YouTube"
        )
        #expect(cleaned.artist == "B.I")
        #expect(cleaned.track == "BTBT")

        let good = LRCLibResponse(id: 1, duration: 220, syncedLyrics: "[00:01.00]Yes")
        let slowed = LRCLibResponse(id: 2, duration: 260, syncedLyrics: "[00:01.00]Slow")
        #expect(LRCLibQueryCleaner.pickBestMatch(from: [slowed], targetDuration: 221) == nil)
        #expect(LRCLibQueryCleaner.pickBestMatch(from: [slowed, good], targetDuration: 221)?.id == 1)

        let thaiCollab = LRCLibQueryCleaner.clean(artist: "P6ICKและSURIYA MQT", track: "1 OF 1")
        #expect(thaiCollab.artist == "P6ICK & SURIYA MQT")
        #expect(thaiCollab.searchQuery == "P6ICK 1 OF 1")

        let karaoke = LRCLibResponse(id: 10, duration: 261, syncedLyrics: "[00:01.00]Phom yok hai thoe")
        let thai = LRCLibResponse(id: 11, duration: 261, syncedLyrics: "[00:01.00]ผมยกให้เธอ")
        #expect(LRCLibQueryCleaner.pickBestMatch(from: [karaoke, thai], targetDuration: 261)?.id == 11)

        let krRom = LRCLibResponse(id: 12, duration: 190, syncedLyrics: "[00:01.00]Annyeonghaseyo")
        let krNative = LRCLibResponse(id: 13, duration: 190, syncedLyrics: "[00:01.00]안녕하세요")
        #expect(LRCLibQueryCleaner.pickBestMatch(from: [krRom, krNative], targetDuration: 190)?.id == 13)

        let jpPlain = LRCLibResponse(id: 14, duration: 210, plainLyrics: "夜に駆ける")
        #expect(LRCLibQueryCleaner.pickBestMatch(from: [jpPlain], targetDuration: 210)?.id == 14)
    }

    @Test func plainLyricsAndSafariCleaner() {
        let doc = LRCParser.plain("Line 1\n\n  Line 2  ", sourceLabel: "YT MUSIC")
        #expect(doc != nil)
        #expect(doc?.isSynced == false)
        #expect(doc?.sourceLabel == "YT MUSIC")
        #expect(doc?.lines.map(\.text) == ["Line 1", "Line 2"])
        #expect(doc?.currentLineIndex(at: 10) == nil)

        #expect(SafariYouTubeMusicLyricsClient.cleanExtractedLyrics("short") == nil)
        #expect(SafariYouTubeMusicLyricsClient.cleanExtractedLyrics("   \n  ") == nil)
        let chinese = SafariYouTubeMusicLyricsClient.cleanExtractedLyrics(
            "\n如果忽遠忽近的灑脫 是你要的自由\n\n那我寧願回到一個人生活\n"
        )
        #expect(chinese == "如果忽遠忽近的灑脫 是你要的自由\n那我寧願回到一個人生活")
    }
}
