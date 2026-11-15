import Foundation
import Testing
@testable import NotchKit

@Suite
struct GitHubPulseTests {
    @Test func parsesSearchJSONAndDetectsStateTransitions() throws {
        let json = """
        {
          "items": [
            {
              "number": 42,
              "title": "Fix race condition",
              "html_url": "https://github.com/pawalit/MyNotchApp/pull/42",
              "repository_url": "https://api.github.com/repos/pawalit/MyNotchApp",
              "draft": false
            }
          ]
        }
        """
        let prs = GitHubPulseParser.parseSearchItems(Data(json.utf8), isReviewRequest: true)
        #expect(prs.count == 1)
        #expect(prs[0].number == 42)
        #expect(prs[0].repo == "pawalit/MyNotchApp")
        #expect(prs[0].isReviewRequest == true)

        // New review request triggers transition
        let added = GitHubPulseParser.diffTransitions(previous: [], current: prs)
        #expect(added.count == 1)

        // Same state on next poll triggers nothing
        let unchanged = GitHubPulseParser.diffTransitions(previous: prs, current: prs)
        #expect(unchanged.isEmpty)
    }
}
