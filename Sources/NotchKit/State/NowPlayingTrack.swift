import Foundation

public struct NowPlayingTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let source: String
    public let isPlaying: Bool
    public let duration: TimeInterval
    public let anchorPosition: TimeInterval
    public let anchorDate: Date
    public let artworkData: Data?

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        source: String,
        isPlaying: Bool,
        duration: TimeInterval,
        anchorPosition: TimeInterval,
        anchorDate: Date = .now,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.source = source
        self.isPlaying = isPlaying
        self.duration = max(0, duration)
        self.anchorPosition = max(0, anchorPosition)
        self.anchorDate = anchorDate
        self.artworkData = artworkData
    }

    public func currentPosition(at date: Date = .now) -> TimeInterval {
        guard isPlaying else { return anchorPosition }
        let elapsed = max(0, date.timeIntervalSince(anchorDate))
        let raw = anchorPosition + elapsed
        return duration > 0 ? min(duration, raw) : raw
    }

    public var trackKey: String {
        "\(artist.lowercased())|\(title.lowercased())"
    }
}

