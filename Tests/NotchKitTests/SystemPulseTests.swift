import Foundation
import Testing
@testable import NotchKit

@Suite
struct SystemPulseTests {
    @Test func parsesPsOutputAndAlertsOnlyAfter30SecondsAbove90Percent() {
        let ps = """
          PID  %CPU COMM
          512  95.4 swift-frontend
          810  12.1 WindowServer
        """
        let procs = SystemPulseParser.parseTopProcesses(ps)
        #expect(procs.count == 2)
        #expect(procs[0].pid == 512)
        #expect(procs[0].cpuPercent == 95.4)
        #expect(procs[0].name == "swift-frontend")

        var tracker = SystemPulseTracker()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // At t0 and t0+20s -> not yet 30s
        #expect(tracker.ingest(procs, at: t0) == nil)
        #expect(tracker.ingest(procs, at: t0.addingTimeInterval(20)) == nil)

        // At t0+31s -> alerts once
        let alert = tracker.ingest(procs, at: t0.addingTimeInterval(31))
        #expect(alert?.pid == 512)

        // Next sample for same PID doesn't re-alert
        #expect(tracker.ingest(procs, at: t0.addingTimeInterval(40)) == nil)
    }
}
