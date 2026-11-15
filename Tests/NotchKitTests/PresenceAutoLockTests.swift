import Foundation
import Testing
@testable import NotchKit

@Suite("PresenceAutoLockTests")
struct PresenceAutoLockTests {
    @Test("WalkAwayCountdownTracker resets when face is present and triggers lock after threshold + countdown")
    func countdownAndLock() {
        var tracker = WalkAwayCountdownTracker(absenceThreshold: 30, countdownDuration: 3)
        let t0 = Date(timeIntervalSince1970: 1000)

        #expect(tracker.recordSample(faceDetected: true, at: t0) == .none)
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(10)) == .none)
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(30)) == .countdown(remainingSeconds: 3))
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(31)) == .countdown(remainingSeconds: 2))
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(33)) == .triggerLock)
    }

    @Test("WalkAwayCountdownTracker cancels cleanly when user returns or presses cancel")
    func cancelAndReturn() {
        var tracker = WalkAwayCountdownTracker(absenceThreshold: 15, countdownDuration: 3)
        let t0 = Date(timeIntervalSince1970: 2000)

        _ = tracker.recordSample(faceDetected: true, at: t0)
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(16)) == .countdown(remainingSeconds: 3))

        // User returns
        #expect(tracker.recordSample(faceDetected: true, at: t0.addingTimeInterval(17)) == .cancelled)
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(25)) == .none)

        // Manual cancel
        _ = tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(35))
        tracker.cancel(at: t0.addingTimeInterval(36))
        #expect(tracker.recordSample(faceDetected: false, at: t0.addingTimeInterval(38)) == .none)
    }
}

