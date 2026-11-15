import Foundation
import Testing
@testable import NotchKit

@Suite("AntigravityWatcherTests")
struct AntigravityWatcherTests {
    @Test("Parses PLANNER_RESPONSE with tool_calls as working")
    func parsesWorkingToolCall() throws {
        let jsonl = """
        {"step_index":1,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-11-15T16:00:00Z","content":"fix bug"}
        {"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-11-15T16:00:02Z","tool_calls":[{"name":"run_command","arguments":{"CommandLine":"swift test"}}]}
        """
        let event = try #require(AntigravityTranscriptParser.parseLatestEvent(
            from: Data(jsonl.utf8),
            sessionID: "conv-123"
        ))
        #expect(event.source == "antigravity")
        #expect(event.session == "conv-123")
        #expect(event.state == .working)
        #expect(event.title == "Running run_command")
    }

    @Test("Parses pending approval / waiting step as waiting")
    func parsesWaitingApproval() throws {
        let jsonl = """
        {"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"run_command"}]}
        {"step_index":3,"source":"MODEL","type":"RUN_COMMAND","status":"WAITING","content":"npm test"}
        """
        let event = try #require(AntigravityTranscriptParser.parseLatestEvent(
            from: Data(jsonl.utf8),
            sessionID: "conv-123"
        ))
        #expect(event.state == .waiting)
    }

    @Test("Parses BypassSandbox run_command and ask_question as waiting")
    func parsesBypassSandboxAndAskQuestionAsWaiting() throws {
        let bypassJsonl = """
        {"step_index":4,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"run_command","args":{"BypassSandbox":"true","CommandLine":"swift test"}}]}
        """
        let bypassEvent = try #require(AntigravityTranscriptParser.parseLatestEvent(
            from: Data(bypassJsonl.utf8),
            sessionID: "conv-123"
        ))
        #expect(bypassEvent.state == .waiting)
        #expect(bypassEvent.title == "Waiting for Approval")

        let askJsonl = """
        {"step_index":5,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"ask_question","args":{"questions":[]}}]}
        """
        let askEvent = try #require(AntigravityTranscriptParser.parseLatestEvent(
            from: Data(askJsonl.utf8),
            sessionID: "conv-123"
        ))
        #expect(askEvent.state == .waiting)
        #expect(askEvent.title == "Waiting for Answer")
    }

    @Test("Parses final PLANNER_RESPONSE without tool_calls as done")
    func parsesFinalResponseAsDone() throws {
        let jsonl = """
        {"step_index":1,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE"}
        {"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","content":"All fixed!"}
        """
        let event = try #require(AntigravityTranscriptParser.parseLatestEvent(
            from: Data(jsonl.utf8),
            sessionID: "conv-123"
        ))
        #expect(event.state == .done)
    }
}

