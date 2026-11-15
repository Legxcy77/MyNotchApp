import Foundation
import Testing
@testable import NotchKit

@Suite struct ErrorLensTests {
    @Test func eventBusParsesErrorLogOnToast() {
        let router = EventBusRouter(token: "tok")
        let json = #"{"title":"tsc failed","subtitle":"npx tsc","tint":"fail","errorLog":"src/a.ts(1,1): error TS2322"}"#
        let req = HTTPRequest(
            method: "POST",
            path: "/toast",
            headers: ["authorization": "Bearer tok"],
            body: Data(json.utf8)
        )
        let res = router.handle(req)
        #expect(res.response.statusCode == 200)
        guard case .postToast(let toast) = res.action else {
            Issue.record("Expected postToast")
            return
        }
        #expect(toast.errorLog == "src/a.ts(1,1): error TS2322")
        #expect(toast.duration == .seconds(8))
    }

    @Test func errorLensModePrecedenceAndClose() {
        var s = NotchState()
        _ = NotchReducer.reduce(&s, .openErrorLens(title: "tsc failed", log: "line1\nline2"))
        #expect(s.mode == .errorLens(title: "tsc failed", log: "line1\nline2"))

        _ = NotchReducer.reduce(&s, .closeErrorLens)
        #expect(s.mode == .collapsed)
    }
}

