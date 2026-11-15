import Foundation

public struct RunRecord: Identifiable, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case command
        case agent
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    public let cwd: String?
    public let exitCode: Int32
    public let duration: TimeInterval
    public let finishedAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        cwd: String? = nil,
        exitCode: Int32,
        duration: TimeInterval,
        finishedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.cwd = cwd
        self.exitCode = exitCode
        self.duration = max(0, duration)
        self.finishedAt = finishedAt
    }

    public var succeeded: Bool { exitCode == 0 }

    public var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds < 60 {
            if duration < 10 && duration > 0 && duration.truncatingRemainder(dividingBy: 1) != 0 {
                return String(format: "%.1fs", duration)
            }
            return "\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)m \(seconds)s"
    }
}

