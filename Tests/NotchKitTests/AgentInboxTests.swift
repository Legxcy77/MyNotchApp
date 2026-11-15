import Foundation
import Testing
@testable import NotchKit

@Suite struct AgentInboxTests {
    @Test func workingUpdatesEarsWithoutPostingToast() {
        var s = NotchState()
        let t0 = Date(timeIntervalSince1970: 1000)
        let ev = ActivityEvent(source: "claude", session: "s1", state: .working, title: "Editing", cwd: "/Users/dev/MyNotchApp")
        let fx = NotchReducer.reduce(&s, .recordActivity(ev, at: t0))

        #expect(fx.isEmpty)
        #expect(s.activeToast == nil)
        #expect(s.workingAgentCount == 1)
        #expect(s.hasActiveAgents)
        #expect(s.agentSessions.first?.cwdBasename == "MyNotchApp")
    }

    @Test func waitingPostsCriticalOrangeToastAndUpdatesSession() {
        var s = NotchState()
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1015)
        _ = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "claude", session: "s1", state: .working, cwd: "/tmp/app"), at: t0))
        let fx = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "claude", session: "s1", state: .waiting, title: "Approve edit?", cwd: "/tmp/app"), at: t1))

        #expect(!fx.isEmpty)
        #expect(s.activeToast?.tint == .waiting)
        #expect(s.activeToast?.priority == .critical)
        #expect(s.workingAgentCount == 0)
        #expect(s.waitingAgentCount == 1)
        #expect(s.agentSessions.first?.startedAt == t0)
        #expect(s.agentSessions.first?.updatedAt == t1)
    }

    @Test func donePostsSuccessToastAndClearsActiveCount() {
        var s = NotchState()
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1030)
        _ = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "codex", session: "c1", state: .working, cwd: "/tmp/api"), at: t0))
        _ = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "codex", session: "c1", state: .done, title: "Finished", cwd: "/tmp/api"), at: t1))

        #expect(s.activeToast?.tint == .success)
        #expect(!s.hasActiveAgents)
        #expect(s.agentSessions.count == 1)
    }

    @Test func clearFinishedAgentsKeepsActiveOnes() {
        var s = NotchState()
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "claude", session: "s1", state: .working), at: t0))
        _ = NotchReducer.reduce(&s, .recordActivity(ActivityEvent(source: "codex", session: "s2", state: .done), at: t0))
        _ = NotchReducer.reduce(&s, .clearFinishedAgents)

        #expect(s.agentSessions.count == 1)
        #expect(s.agentSessions.first?.session == "s1")
    }
}
