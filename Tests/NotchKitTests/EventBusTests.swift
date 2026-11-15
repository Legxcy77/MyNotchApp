import Foundation
import Testing
@testable import NotchKit

@Suite struct HTTPRequestParserTests {
    @Test func parsesCompletePostRequest() {
        let body = #"{"title":"Build done"}"#
        let raw = "POST /toast HTTP/1.1\r\nHost: localhost:7777\r\nAuthorization: Bearer secret123\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let result = HTTPRequestParser.parse(Data(raw.utf8))
        guard case .complete(let req) = result else {
            Issue.record("Expected complete request, got \(result)")
            return
        }
        #expect(req.method == "POST")
        #expect(req.path == "/toast")
        #expect(req.header("authorization") == "Bearer secret123")
        #expect(String(data: req.body, encoding: .utf8) == body)
    }

    @Test func waitsForIncompleteBody() {
        let raw = "POST /toast HTTP/1.1\r\nContent-Length: 20\r\n\r\n{\"title\":\"hi"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .incomplete)
    }

    @Test func waitsForIncompleteHeaders() {
        let raw = "GET /health HTTP/1.1\r\nHost: localhost"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .incomplete)
    }

    @Test func rejectsMalformedRequestLine() {
        let raw = "BADREQUEST\r\n\r\n"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .invalid)
    }
}

@Suite struct EventBusRouterTests {
    private let token = "test-token-abc"

    private func makeRequest(method: String = "POST", path: String, auth: String? = "Bearer test-token-abc", json: String = "") -> HTTPRequest {
        var headers: [String: String] = [:]
        if let auth { headers["authorization"] = auth }
        return HTTPRequest(method: method, path: path, headers: headers, body: Data(json.utf8))
    }

    @Test func rejectsMissingOrWrongTokenWith401() {
        let router = EventBusRouter(token: token)
        let missing = router.handle(makeRequest(path: "/health", auth: nil))
        #expect(missing.response.statusCode == 401)
        #expect(missing.action == nil)

        let wrong = router.handle(makeRequest(method: "GET", path: "/health", auth: "Bearer nope"))
        #expect(wrong.response.statusCode == 401)
        #expect(wrong.action == nil)
    }

    @Test func healthReturns200() {
        let router = EventBusRouter(token: token)
        let res = router.handle(makeRequest(method: "GET", path: "/health"))
        #expect(res.response.statusCode == 200)
        #expect(res.action == nil)
    }

    @Test func toastEndpointMapsFieldsAndTintAliases() {
        let router = EventBusRouter(token: token)
        let json = #"{"title":"Deployed","subtitle":"prod","symbol":"checkmark","tint":"ok","priority":"high","ttl":5,"key":"dep"}"#
        let res = router.handle(makeRequest(path: "/toast", json: json))
        #expect(res.response.statusCode == 200)
        guard case .postToast(let toast) = res.action else {
            Issue.record("Expected postToast action")
            return
        }
        #expect(toast.title == "Deployed")
        #expect(toast.subtitle == "prod")
        #expect(toast.symbol == "checkmark")
        #expect(toast.tint == .success)
        #expect(toast.priority == .high)
        #expect(toast.duration == .seconds(5))
        #expect(toast.key == "dep")
    }

    @Test func progressUpdatesInPlaceAndCompletesAtOne() {
        let router = EventBusRouter(token: token)
        let mid = router.handle(makeRequest(path: "/progress", json: #"{"key":"dl","title":"Downloading","value":0.5,"subtitle":"bundle"}"#))
        #expect(mid.response.statusCode == 200)
        guard case .postToast(let t1) = mid.action else {
            Issue.record("Expected postToast")
            return
        }
        #expect(t1.key == "dl")
        #expect(t1.subtitle == "50% · bundle")
        #expect(t1.tint == .info)

        let done = router.handle(makeRequest(path: "/progress", json: #"{"key":"dl","title":"Downloading","value":1.0}"#))
        #expect(done.response.statusCode == 200)
        guard case .postToast(let t2) = done.action else {
            Issue.record("Expected postToast")
            return
        }
        #expect(t2.key == "dl")
        #expect(t2.tint == .success)
        #expect(t2.duration == .seconds(1.5))
    }

    @Test func activityEndpointParsesStates() {
        let router = EventBusRouter(token: token)
        let json = #"{"source":"claude","session":"s1","state":"waiting","title":"Approve edit?","cwd":"/Users/dev/app"}"#
        let res = router.handle(makeRequest(path: "/activity", json: json))
        #expect(res.response.statusCode == 200)
        guard case .activity(let ev) = res.action else {
            Issue.record("Expected activity action")
            return
        }
        #expect(ev.source == "claude")
        #expect(ev.session == "s1")
        #expect(ev.state == .waiting)
        #expect(ev.title == "Approve edit?")
        #expect(ev.cwd == "/Users/dev/app")
    }

    @Test func invalidJsonReturns400AndUnknownPathReturns404() {
        let router = EventBusRouter(token: token)
        #expect(router.handle(makeRequest(path: "/toast", json: "{bad")).response.statusCode == 400)
        #expect(router.handle(makeRequest(path: "/nope", json: "{}")).response.statusCode == 404)
    }
}
