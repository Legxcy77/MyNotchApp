import Foundation
import Testing
@testable import NotchKit

@Suite struct SmartClipboardTests {
    @Test func detectsAndDecodesJWT() {
        // {"alg":"HS256","typ":"JWT"}.{"sub":"123","name":"Dev"}.sig
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMiLCJuYW1lIjoiRGV2In0.signature"
        guard case .jwt(let header, let payload) = SmartClipboardDetector.detect(jwt) else {
            Issue.record("Expected JWT match")
            return
        }
        #expect(header.contains("HS256"))
        #expect(payload.contains("Dev"))
    }

    @Test func detectsAndPrettyPrintsJSON() {
        guard case .json(let pretty) = SmartClipboardDetector.detect(#"{"b":2,"a":1}"#) else {
            Issue.record("Expected JSON match")
            return
        }
        #expect(pretty.contains("\n"))
        #expect(pretty.contains("\"a\" : 1"))
    }

    @Test func detectsUnixEpochSecondsAndMillis() {
        guard case .unixEpoch(let sec1, let fmt1) = SmartClipboardDetector.detect("1700000000") else {
            Issue.record("Expected epoch seconds match")
            return
        }
        #expect(sec1 == 1_700_000_000)
        #expect(!fmt1.isEmpty)

        guard case .unixEpoch(let sec2, _) = SmartClipboardDetector.detect("1700000000000") else {
            Issue.record("Expected epoch millis match")
            return
        }
        #expect(sec2 == 1_700_000_000)
    }

    @Test func detectsHexColor() {
        guard case .hexColor(let hex, let r, let g, let b, let a) = SmartClipboardDetector.detect("#FF8000") else {
            Issue.record("Expected hexColor match")
            return
        }
        #expect(hex == "#FF8000")
        #expect(r == 1.0)
        #expect(abs(g - (128.0 / 255.0)) < 0.01)
        #expect(b == 0.0)
        #expect(a == 1.0)
    }

    @Test func detectsUUID() {
        let raw = "550e8400-e29b-41d4-a716-446655440000"
        guard case .uuid(let u) = SmartClipboardDetector.detect(raw) else {
            Issue.record("Expected UUID match")
            return
        }
        #expect(u == raw.uppercased())
    }

    @Test func detectsURLEncodedAndBase64() {
        guard case .urlEncoded(let decodedURL) = SmartClipboardDetector.detect("hello%20world%21") else {
            Issue.record("Expected urlEncoded match")
            return
        }
        #expect(decodedURL == "hello world!")

        guard case .base64(let decodedB64) = SmartClipboardDetector.detect("SGVsbG8gd29ybGQ=") else {
            Issue.record("Expected base64 match")
            return
        }
        #expect(decodedB64 == "Hello world")
    }

    @Test func ignoresPlainText() {
        #expect(SmartClipboardDetector.detect("just some normal text") == nil)
    }
}
