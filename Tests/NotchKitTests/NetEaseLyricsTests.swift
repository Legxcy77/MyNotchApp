import Foundation
import os
import Testing
@testable import NotchKit

@Suite("NetEaseLyricsTests")
struct NetEaseLyricsTests {
    @Test("NetEaseLyricsClient searches songId, filters by duration ±4s, and fetches synced LRC")
    func fetchesSyncedLyricsFromNetEase() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NetEaseMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = NetEaseLyricsClient(session: session)

        NetEaseMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            if url.path.contains("/api/search/get") {
                let json = """
                {
                  "result": {
                    "songs": [
                      { "id": 111, "name": "猜不透 (Live)", "duration": 240000, "artists": [{"name": "丁当"}] },
                      { "id": 222, "name": "猜不透 (说唱版)", "duration": 182000, "artists": [{"name": "Lil Ghost"}] }
                    ]
                  },
                  "code": 200
                }
                """
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            } else if url.path.contains("/api/song/lyric") {
                #expect(url.query?.contains("id=222") == true)
                let json = """
                {
                  "lrc": {
                    "lyric": "[00:12.00]如果那天\\n[00:15.50]你没有走"
                  },
                  "code": 200
                }
                """
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            }
            throw URLError(.badURL)
        }

        let doc = try await client.fetchLyrics(artist: "Lil Ghost", track: "猜不透 (说唱版)", duration: 180)
        let parsed = try #require(doc)
        #expect(parsed.sourceLabel == "NetEase")
        #expect(parsed.lines.count == 2)
        #expect(parsed.lines[0].text == "如果那天")
        #expect(abs(parsed.lines[1].time - 15.5) < 0.01)
    }

    @Test("LRCDocument.withOffset shifts line and word timestamps accurately")
    func documentWithOffsetShiftsTimestamps() {
        let raw = "[00:10.00]<00:10.00>Hello <00:10.50>world"
        let doc = LRCParser.parse(raw)
        #expect(doc.lines.count == 1)
        #expect(doc.lines[0].words.count == 2)
        #expect(doc.lines[0].text == "Hello world")

        let shifted = doc.withOffset(-0.5)
        #expect(abs(shifted.offset - (-0.5)) < 0.001)
        #expect(abs(shifted.lines[0].time - 9.5) < 0.001)
        #expect(abs(shifted.lines[0].words[1].time - 10.0) < 0.001)
    }
}

private final class NetEaseMockURLProtocol: URLProtocol {
    private static let lock = OSAllocatedUnfairLock<(@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?>(initialState: nil)

    static func setHandler(_ newValue: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.withLock { $0 = newValue }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.lock.withLock({ $0 }) else {
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
