import Foundation
import Testing
@testable import NotchKit

@Suite
struct RunTimelineTests {
    @Test func capsRunHistoryAt30NewestFirst() {
        var state = NotchState()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        for i in 1...35 {
            let record = RunRecord(
                kind: .command,
                title: "cmd-\(i)",
                cwd: "/tmp/repo",
                exitCode: i % 2 == 0 ? 0 : 1,
                duration: Double(i),
                finishedAt: base.addingTimeInterval(Double(i))
            )
            _ = NotchReducer.reduce(&state, .recordRun(record))
        }

        #expect(state.runHistory.count == 30)
        #expect(state.runHistory.first?.title == "cmd-35")
        #expect(state.runHistory.last?.title == "cmd-6")
    }

    @Test func recordsAgentCompletionIntoRunHistoryWithDurationAndCwd() {
        var state = NotchState()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(12.4)

        _ = NotchReducer.reduce(&state, .recordActivity(
            ActivityEvent(source: "claude", session: "s1", state: .working, title: "Refactor auth", cwd: "/Users/dev/app"),
            at: t0
        ))
        #expect(state.runHistory.isEmpty)

        _ = NotchReducer.reduce(&state, .recordActivity(
            ActivityEvent(source: "claude", session: "s1", state: .done, title: "Refactor auth", cwd: "/Users/dev/app"),
            at: t1
        ))

        #expect(state.runHistory.count == 1)
        let entry = state.runHistory[0]
        #expect(entry.kind == .agent)
        #expect(entry.title == "Refactor auth")
        #expect(entry.cwd == "/Users/dev/app")
        #expect(entry.exitCode == 0)
        #expect(abs(entry.duration - 12.4) < 0.01)

        // Failed agent records non-zero exitCode
        _ = NotchReducer.reduce(&state, .recordActivity(
            ActivityEvent(source: "codex", session: "s2", state: .failed, title: "Build failed", cwd: "/Users/dev/api"),
            at: t1.addingTimeInterval(5)
        ))
        #expect(state.runHistory.count == 2)
        #expect(state.runHistory[0].exitCode == 1)
        #expect(state.runHistory[0].succeeded == false)
    }

    @Test func switchesExpandedTabAndClearsHistory() {
        var state = NotchState()
        #expect(state.expandedTab == .overview)

        _ = NotchReducer.reduce(&state, .setExpandedTab(.timeline))
        #expect(state.expandedTab == .timeline)

        _ = NotchReducer.reduce(&state, .recordRun(RunRecord(kind: .command, title: "swift test", exitCode: 0, duration: 2.0)))
        #expect(state.runHistory.count == 1)

        _ = NotchReducer.reduce(&state, .clearRunHistory)
        #expect(state.runHistory.isEmpty)
    }
}
