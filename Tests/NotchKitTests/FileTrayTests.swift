import Foundation
import Testing
@testable import NotchKit

@Suite struct FileTrayTests {
    @Test func stagesUniqueStandardizedURLs() {
        var s = NotchState()
        let a = URL(fileURLWithPath: "/tmp/a.txt")
        let b = URL(fileURLWithPath: "/tmp/b.png")
        let aDup = URL(fileURLWithPath: "/tmp/./a.txt")

        _ = NotchReducer.reduce(&s, .stageFiles([a, b, aDup]))
        #expect(s.stagedFiles.count == 2)
        #expect(s.stagedFiles[0].lastPathComponent == "a.txt")
        #expect(s.stagedFiles[1].lastPathComponent == "b.png")
    }

    @Test func removeAndClearStagedFiles() {
        var s = NotchState()
        let a = URL(fileURLWithPath: "/tmp/a.txt")
        let b = URL(fileURLWithPath: "/tmp/b.png")
        _ = NotchReducer.reduce(&s, .stageFiles([a, b]))
        _ = NotchReducer.reduce(&s, .removeStagedFile(a))
        #expect(s.stagedFiles == [b])
        _ = NotchReducer.reduce(&s, .clearStagedFiles)
        #expect(s.stagedFiles.isEmpty)
    }
}
