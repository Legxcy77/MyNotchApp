import Foundation

public struct LRCLine: Equatable, Sendable, Identifiable {
    public let id: Int
    public let time: TimeInterval
    public let text: String

    public init(id: Int, time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public struct LRCDocument: Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let offset: TimeInterval
    public let lines: [LRCLine]

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        offset: TimeInterval = 0,
        lines: [LRCLine] = []
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.offset = offset
        self.lines = lines
    }

    /// Binary-searches the last lyric line whose timestamp is `<= position`.
    public func currentLineIndex(at position: TimeInterval) -> Int? {
        guard !lines.isEmpty, position >= lines[0].time else { return nil }
        var low = 0
        var high = lines.count - 1
        var result = 0
        while low <= high {
            let mid = low + (high - low) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }
}

public enum LRCParser {
    public static func parse(_ raw: String) -> LRCDocument {
        var title: String?
        var artist: String?
        var album: String?
        var offsetSeconds: TimeInterval = 0
        var entries: [(time: TimeInterval, text: String)] = []

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var index = line.startIndex
            var timestamps: [TimeInterval] = []

            while index < line.endIndex, line[index] == "[" {
                guard let close = line[index...].firstIndex(of: "]") else { break }
                let tag = String(line[line.index(after: index)..<close])

                if let time = parseTimestamp(tag) {
                    timestamps.append(time)
                } else if timestamps.isEmpty {
                    parseMetadata(tag, title: &title, artist: &artist, album: &album, offset: &offsetSeconds)
                }
                index = line.index(after: close)
            }

            guard !timestamps.isEmpty else { continue }
            let text = line[index...].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            for t in timestamps {
                entries.append((time: t, text: text))
            }
        }

        let sorted = entries
            .map { (time: max(0, $0.time + offsetSeconds), text: $0.text) }
            .sorted { $0.time < $1.time }

        let lines = sorted.enumerated().map { idx, entry in
            LRCLine(id: idx, time: entry.time, text: entry.text)
        }

        return LRCDocument(
            title: title,
            artist: artist,
            album: album,
            offset: offsetSeconds,
            lines: lines
        )
    }

    private static func parseMetadata(
        _ tag: String,
        title: inout String?,
        artist: inout String?,
        album: inout String?,
        offset: inout TimeInterval
    ) {
        guard let colon = tag.firstIndex(of: ":") else { return }
        let key = tag[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
        let value = tag[tag.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }

        switch key {
        case "ti": title = value
        case "ar": artist = value
        case "al": album = value
        case "offset":
            if let ms = Double(value) {
                offset = ms / 1000.0
            }
        default: break
        }
    }

    private static func parseTimestamp(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              minutes >= 0 else { return nil }

        let secParts = parts[1].split(separator: ".", maxSplits: 1)
        guard let seconds = Double(secParts[0]), seconds >= 0, seconds < 60 else { return nil }

        var fraction: Double = 0
        if secParts.count == 2 {
            let fracStr = secParts[1]
            guard !fracStr.isEmpty, let fracVal = Double(fracStr) else { return nil }
            fraction = fracVal / pow(10.0, Double(fracStr.count))
        }
        return minutes * 60.0 + seconds + fraction
    }
}

