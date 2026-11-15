import Foundation

public struct FocusSession: Equatable, Sendable {
    public let startedAt: Date
    public let duration: TimeInterval

    public init(startedAt: Date = .now, duration: TimeInterval) {
        self.startedAt = startedAt
        self.duration = max(1, duration)
    }

    public var endDate: Date {
        startedAt.addingTimeInterval(duration)
    }

    public func progress(at now: Date = .now) -> Double {
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        return min(1.0, elapsed / duration)
    }

    public func remainingSeconds(at now: Date = .now) -> Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    public func formattedRemaining(at now: Date = .now) -> String {
        let rem = remainingSeconds(at: now)
        let mins = rem / 60
        let secs = rem % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
