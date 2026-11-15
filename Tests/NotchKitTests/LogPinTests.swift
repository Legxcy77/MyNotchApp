import Foundation
import Testing
@testable import NotchKit

@Suite struct LogPinTests {
    @Test func matchesDefaultErrorPatterns() {
        let matcher = LogLineMatcher()
        let chunk = """
        [INFO] Server started on :3000
        [ERROR] Database connection refused
        [INFO] Retrying...
        """
        #expect(matcher.matchingLines(in: chunk) == ["[ERROR] Database connection refused"])
    }

    @Test func supportsExceptionFatalAndCustomRegex() {
        let defaultMatcher = LogLineMatcher()
        #expect(defaultMatcher.matchingLines(in: "Unhandled Exception: null ref").count == 1)
        #expect(defaultMatcher.matchingLines(in: "FATAL: out of memory").count == 1)
        #expect(defaultMatcher.matchingLines(in: "all good").isEmpty)

        let custom = LogLineMatcher(pattern: "WARN|TIMEOUT")
        #expect(custom.matchingLines(in: "request TIMEOUT after 5s") == ["request TIMEOUT after 5s"])
    }
}

