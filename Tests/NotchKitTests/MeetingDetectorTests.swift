import Foundation
import Testing
@testable import NotchKit

@Suite
struct MeetingDetectorTests {
    @Test func extractsMeetZoomAndTeamsURLs() {
        let meet = MeetingDetector.extractJoinURL(from: [
            nil,
            "Join Google Meet: https://meet.google.com/abc-defg-hij?authuser=0"
        ])
        #expect(meet?.absoluteString == "https://meet.google.com/abc-defg-hij?authuser=0")

        let zoom = MeetingDetector.extractJoinURL(from: [
            "https://us02web.zoom.us/j/123456789?pwd=xyz"
        ])
        #expect(zoom?.host == "us02web.zoom.us")

        let teams = MeetingDetector.extractJoinURL(from: [
            "Location: Microsoft Teams",
            "Click here: https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc"
        ])
        #expect(teams?.host == "teams.microsoft.com")

        let nonMeeting = MeetingDetector.extractJoinURL(from: [
            "Docs at https://github.com/apple/swift"
        ])
        #expect(nonMeeting == nil)
    }

    @Test func detectsTMinus5MinWindowAndFormatsCountdown() {
        let start = Date(timeIntervalSince1970: 1_700_000_600)
        let meeting = UpcomingMeeting(
            id: "evt-1",
            title: "Daily Standup",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            joinURL: URL(string: "https://meet.google.com/abc-defg-hij")!
        )

        // 10 min before -> not urgent
        #expect(MeetingDetector.isWithinCountdownWindow(meeting, now: start.addingTimeInterval(-600)) == false)
        // 4m 30s before -> urgent
        #expect(MeetingDetector.isWithinCountdownWindow(meeting, now: start.addingTimeInterval(-270)) == true)
        #expect(MeetingDetector.countdownText(until: start, now: start.addingTimeInterval(-270)) == "4:30")
        // Already started -> NOW
        #expect(MeetingDetector.countdownText(until: start, now: start.addingTimeInterval(30)) == "NOW")
        // After endDate -> not urgent
        #expect(MeetingDetector.isWithinCountdownWindow(meeting, now: start.addingTimeInterval(2000)) == false)
    }
}

