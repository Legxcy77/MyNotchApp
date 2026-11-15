import Foundation

public struct LRCWord: Equatable, Sendable, Identifiable {
    public let id: Int
    public let time: TimeInterval
    public let text: String

    public init(id: Int, time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public struct LRCLine: Equatable, Sendable, Identifiable {
    public let id: Int
    public let time: TimeInterval
    public let text: String
    public let words: [LRCWord]

    public init(id: Int, time: TimeInterval, text: String, words: [LRCWord] = []) {
        self.id = id
        self.time = time
        self.text = text
        self.words = words
    }
}

public struct LRCDocument: Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let offset: TimeInterval
    public let lines: [LRCLine]
    public let isSynced: Bool
    public let sourceLabel: String

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        offset: TimeInterval = 0,
        lines: [LRCLine] = [],
        isSynced: Bool = true,
        sourceLabel: String = "LRCLIB"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.offset = offset
        self.lines = lines
        self.isSynced = isSynced
        self.sourceLabel = sourceLabel
    }

    /// Binary-searches the last lyric line whose timestamp is `<= position`.
    public func currentLineIndex(at position: TimeInterval) -> Int? {
        guard isSynced, !lines.isEmpty, position >= lines[0].time else { return nil }
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

    public func withOffset(_ delta: TimeInterval) -> LRCDocument {
        let shiftedLines = lines.map { line in
            let shiftedWords = line.words.map { word in
                LRCWord(id: word.id, time: max(0, word.time + delta), text: word.text)
            }
            return LRCLine(
                id: line.id,
                time: max(0, line.time + delta),
                text: line.text,
                words: shiftedWords
            )
        }
        return LRCDocument(
            title: title,
            artist: artist,
            album: album,
            offset: offset + delta,
            lines: shiftedLines,
            isSynced: isSynced,
            sourceLabel: sourceLabel
        )
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
            .map { entry -> (time: TimeInterval, text: String, words: [LRCWord]) in
                let (cleanText, parsedWords) = parseInlineWords(from: entry.text, lineTime: entry.time, offset: offsetSeconds)
                return (time: max(0, entry.time + offsetSeconds), text: cleanText, words: parsedWords)
            }
            .sorted { $0.time < $1.time }

        let lines = sorted.enumerated().map { idx, entry in
            LRCLine(id: idx, time: entry.time, text: entry.text, words: entry.words)
        }

        return LRCDocument(
            title: title,
            artist: artist,
            album: album,
            offset: offsetSeconds,
            lines: lines,
            isSynced: true,
            sourceLabel: "LRCLIB"
        )
    }

    public static func plain(
        _ raw: String,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        sourceLabel: String = "LRCLIB"
    ) -> LRCDocument? {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { LRCLine(id: $0.offset, time: 0, text: $0.element) }
        guard !lines.isEmpty else { return nil }
        return LRCDocument(
            title: title,
            artist: artist,
            album: album,
            offset: 0,
            lines: lines,
            isSynced: false,
            sourceLabel: sourceLabel
        )
    }

    private static func parseInlineWords(
        from rawText: String,
        lineTime: TimeInterval,
        offset: TimeInterval
    ) -> (cleanText: String, words: [LRCWord]) {
        guard rawText.contains("<") else {
            return (rawText, [])
        }
        var words: [LRCWord] = []
        var clean = ""
        var idx = rawText.startIndex
        var currentWordTime = lineTime
        var wordID = 0

        while idx < rawText.endIndex {
            if rawText[idx] == "<", let close = rawText[idx...].firstIndex(of: ">") {
                let tag = String(rawText[rawText.index(after: idx)..<close])
                if let t = parseTimestamp(tag) {
                    currentWordTime = t
                    idx = rawText.index(after: close)
                    continue
                }
            }
            let nextTag = rawText[idx...].firstIndex(of: "<") ?? rawText.endIndex
            let segment = String(rawText[idx..<nextTag])
            if !segment.isEmpty {
                clean += segment
                words.append(LRCWord(
                    id: wordID,
                    time: max(0, currentWordTime + offset),
                    text: segment
                ))
                wordID += 1
            }
            idx = nextTag
        }

        let trimmed = clean.trimmingCharacters(in: .whitespaces)
        return (trimmed.isEmpty ? rawText : trimmed, words)
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

