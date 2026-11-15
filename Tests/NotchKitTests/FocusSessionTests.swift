import Foundation
import Testing
@testable import NotchKit

@Suite
struct FocusSessionTests {
    @Test func computesProgressAndRemainingTime() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = FocusSession(startedAt: start, duration: 25 * 60)

        #expect(session.progress(at: start) == 0)
        #expect(session.formattedRemaining(at: start) == "25:00")

        let half = start.addingTimeInterval(12.5 * 60)
        #expect(abs(session.progress(at: half) - 0.5) < 0.001)
        #expect(session.formattedRemaining(at: half) == "12:30")

        let end = start.addingTimeInterval(26 * 60)
        #expect(session.progress(at: end) == 1.0)
        #expect(session.formattedRemaining(at: end) == "00:00")
    }

    @Test func reducerStartsAndStopsFocusSession() {
        var state = NotchState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = NotchReducer.reduce(&state, .startFocus(minutes: 15, at: now))
        #expect(state.focusSession?.duration == TimeInterval(15 * 60))

        _ = NotchReducer.reduce(&state, .stopFocus)
        #expect(state.focusSession == nil)
    }
}
