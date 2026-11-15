import Foundation
import Testing
@testable import NotchKit

@Suite
struct GeminiClientTests {
    @Test func extractsTextDeltaFromSSELine() {
        let line = #"data: {"candidates":[{"content":{"parts":[{"text":"Hello "}]}}]}"#
        #expect(GeminiClient.extractDelta(fromSSELine: line) == "Hello ")

        #expect(GeminiClient.extractDelta(fromSSELine: "event: message") == nil)
        #expect(GeminiClient.extractDelta(fromSSELine: "data: [DONE]") == nil)
        #expect(GeminiClient.extractDelta(fromSSELine: "") == nil)
    }
}
