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
    }
}
