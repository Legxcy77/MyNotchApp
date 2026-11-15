import Foundation
import Testing
@testable import NotchKit

@Suite struct AgentConflictDetectorTests {
    @Test func detectsConfirmedSameFileConflictBetweenActiveAgents() {
        let now = Date(timeIntervalSince1970: 10_000)
        let s1 = AgentSession(
            source: "claude",
            session: "s1",
            state: .working,
            title: "Editing UserService",
            cwd: "/repo/wt-a",
            repo: "MyApp",
            worktree: "/repo/wt-a",
            branch: "feat/auth",
            modifiedFiles: ["/repo/Sources/UserService.swift"],
            startedAt: now.addingTimeInterval(-30),
            updatedAt: now.addingTimeInterval(-5)
        )
        let s2 = AgentSession(
            source: "antigravity",
            session: "s2",
            state: .waiting,
            title: "Waiting for Approval",
            cwd: "/repo/wt-b",
            repo: "MyApp",
            worktree: "/repo/wt-b",
            branch: "feat/profile",
            modifiedFiles: ["/repo/Sources/../Sources/UserService.swift"],
            startedAt: now.addingTimeInterval(-20),
            updatedAt: now
        )

        let conflicts = AgentConflictDetector.detect(sessions: [s1, s2], now: now)
        let sameFile = conflicts.first { $0.kind == .sameFileModified }
        #expect(sameFile != nil)
        #expect(sameFile?.confidence == .confirmed)
        #expect(sameFile?.filePath == "/repo/Sources/UserService.swift")
        #expect(sameFile?.sessions.count == 2)
    }

    @Test func detectsRecentFileOverlapSameBranchSharedWorktreeAndStaleSession() {
        let now = Date(timeIntervalSince1970: 20_000)
        let activeA = AgentSession(
            source: "claude",
            session: "a",
            state: .working,
            cwd: "/repo/main",
            repo: "MyApp",
            worktree: "/repo/main",
            branch: "main",
            modifiedFiles: ["/repo/main/A.swift"],
            startedAt: now.addingTimeInterval(-60),
            updatedAt: now
        )
        let recentDoneB = AgentSession(
            source: "codex",
            session: "b",
            state: .done,
            cwd: "/repo/wt-2",
            repo: "MyApp",
            worktree: "/repo/wt-2",
            branch: "feat/x",
            modifiedFiles: ["/repo/main/A.swift"],
            startedAt: now.addingTimeInterval(-180),
            updatedAt: now.addingTimeInterval(-60)
        )
        let activeC = AgentSession(
            source: "antigravity",
            session: "c",
            state: .working,
            cwd: "/repo/main",
            repo: "MyApp",
            worktree: "/repo/main",
            branch: "main",
            modifiedFiles: ["/repo/main/C.swift"],
            startedAt: now.addingTimeInterval(-1_200),
            updatedAt: now.addingTimeInterval(-1_000)
        )

        let conflicts = AgentConflictDetector.detect(sessions: [activeA, recentDoneB, activeC], now: now)
        #expect(conflicts.contains { $0.kind == .sameFileRecentlyModified && $0.confidence == .warning })
        #expect(conflicts.contains { $0.kind == .sameBranchConcurrentWork && $0.confidence == .warning })
        #expect(conflicts.contains { $0.kind == .sharedWorktree && $0.confidence == .warning })
        #expect(conflicts.contains { $0.kind == .staleSession && $0.confidence == .warning })
    }

    @Test func avoidsFalsePositivesForDisjointWork() {
        let now = Date(timeIntervalSince1970: 30_000)
        let s1 = AgentSession(
            source: "claude",
            session: "1",
            state: .working,
            cwd: "/repo-a",
            repo: "RepoA",
            worktree: "/repo-a",
            branch: "feat/1",
            modifiedFiles: ["/repo-a/Foo.swift"],
            startedAt: now,
            updatedAt: now
        )
        let s2 = AgentSession(
            source: "antigravity",
            session: "2",
            state: .working,
            cwd: "/repo-b",
            repo: "RepoB",
            worktree: "/repo-b",
            branch: "feat/2",
            modifiedFiles: ["/repo-b/Bar.swift"],
            startedAt: now,
            updatedAt: now
        )

        let conflicts = AgentConflictDetector.detect(sessions: [s1, s2], now: now)
        #expect(conflicts.isEmpty)
    }

    @Test func reducerDeduplicatesConfirmedConflictToastsAndRouterParsesFields() {
        let now = Date(timeIntervalSince1970: 40_000)
        var state = NotchState()
        let router = EventBusRouter(token: "tok")

        let body1 = #"{"source":"claude","session":"s1","state":"working","repo":"App","branch":"main","modifiedFiles":["/app/A.swift"]}"#
        let res1 = router.handle(HTTPRequest(
            method: "POST",
            path: "/activity",
            headers: ["authorization": "Bearer tok"],
            body: Data(body1.utf8)
        ))
        #expect(res1.response.statusCode == 200)
        guard case .activity(let ev1) = res1.action else {
            Issue.record("Expected activity event")
            return
        }
        #expect(ev1.repo == "App")
        #expect(ev1.branch == "main")
        #expect(ev1.modifiedFiles == ["/app/A.swift"])
        _ = NotchReducer.reduce(&state, .recordActivity(ev1, at: now))

        let ev2 = ActivityEvent(
            source: "antigravity",
            session: "s2",
            state: .working,
            repo: "App",
            branch: "feat/x",
            modifiedFiles: ["/app/A.swift"]
        )
        let fx2 = NotchReducer.reduce(&state, .recordActivity(ev2, at: now.addingTimeInterval(2)))
        #expect(state.agentConflicts.contains { $0.kind == .sameFileModified })
        #expect(state.activeToast?.tint == .waiting)
        #expect(!fx2.isEmpty)

        // Repeat identical activity should not re-post duplicate conflict toast
        let fxRepeat = NotchReducer.reduce(&state, .recordActivity(ev2, at: now.addingTimeInterval(4)))
        #expect(fxRepeat.isEmpty)
    }
}

