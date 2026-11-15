import Foundation

public struct TerminalTailBuffer: Equatable, Sendable {
    public let capacity: Int
    public private(set) var lines: [String] = []
    public private(set) var lastErrorLine: String?

    public init(capacity: Int = 5) {
        self.capacity = max(1, capacity)
    }

    public mutating func append(_ rawLine: String) {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(trimmed)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
        if Self.isErrorLine(trimmed) {
            lastErrorLine = trimmed
        }
    }

    public mutating func clear() {
        lines.removeAll()
        lastErrorLine = nil
    }

    public static func isErrorLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("error:")
            || lower.contains("fatal:")
            || lower.contains("exception")
            || lower.contains("failed")
            || lower.contains("✘")
    }
}

public enum MissionControlSummary {
    public static func formatElapsed(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public static func formattedTicker(title: String, elapsedSeconds: Int) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cleanTitle) · \(formatElapsed(elapsedSeconds))"
    }
}

