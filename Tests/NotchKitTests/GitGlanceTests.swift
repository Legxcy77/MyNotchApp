import Foundation
import Testing
@testable import NotchKit

@Suite struct GitGlanceTests {
    @Test func parsesPorcelainV2BranchAheadBehindAndDirtyCount() {
        let output = """
        # branch.oid 0123456789abcdef
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -1
        1 .M N... 100644 100644 100644 abc def Sources/App.swift
        ? untracked.txt
        """
        let status = GitStatusParser.parsePorcelainV2(output, repoRoot: "/Users/dev/MyNotchApp")
        #expect(status?.repoName == "MyNotchApp")
        #expect(status?.branch == "main")
        #expect(status?.ahead == 2)
        #expect(status?.behind == 1)
        #expect(status?.dirtyCount == 2)
    }

    @Test func handlesCleanDetachedOrNoUpstreamRepo() {
        let output = """
        # branch.oid 0123456
        # branch.head feat/notch
        """
        let status = GitStatusParser.parsePorcelainV2(output, repoRoot: "/tmp/api")
        #expect(status?.branch == "feat/notch")
        #expect(status?.ahead == 0)
        #expect(status?.behind == 0)
        #expect(status?.dirtyCount == 0)
    }
}

