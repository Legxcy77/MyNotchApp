import Foundation

public struct UpcomingMeeting: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let joinURL: URL

    public init(id: String, title: String, startDate: Date, endDate: Date, joinURL: URL) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.joinURL = joinURL
    }
}

public enum MeetingDetector {
    private static let supportedHosts = [
        "meet.google.com",
        "zoom.us",
        "teams.microsoft.com",
        "teams.live.com",
        "webex.com",
        "around.co",
        "gather.town",
        "cal.com"
    ]

    public static func extractJoinURL(from candidates: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for candidate in candidates {
            guard let text = candidate, !text.isEmpty else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            for match in matches {
                guard let url = match.url,
                      let host = url.host?.lowercased(),
                      supportedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else {
                    continue
                }
                return url
            }
        }
        return nil
    }

    public static func isWithinCountdownWindow(_ meeting: UpcomingMeeting, now: Date = .now) -> Bool {
        let lead = meeting.startDate.timeIntervalSince(now)
        return lead <= 5 * 60 && now < meeting.endDate
    }

    public static func countdownText(until startDate: Date, now: Date = .now) -> String {
        let remaining = Int(startDate.timeIntervalSince(now).rounded(.up))
        if remaining <= 0 { return "NOW" }
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

