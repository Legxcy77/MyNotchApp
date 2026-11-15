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

    @Test("store.airDropStagedFiles forwards staged URLs to AirDrop handler and skips empty tray")
    @MainActor
    func airDropStagedFilesCallsHandler() {
        let store = NotchStore()
        var sharedBatches: [[URL]] = []
        store.onAirDrop = { urls in
            sharedBatches.append(urls)
            return true
        }

        // Empty tray does nothing
        #expect(store.airDropStagedFiles() == false)
        #expect(sharedBatches.isEmpty)

        let a = URL(fileURLWithPath: "/tmp/report.pdf")
        let b = URL(fileURLWithPath: "/tmp/photo.png")
        store.send(.stageFiles([a, b]))

        #expect(store.airDropStagedFiles() == true)
        #expect(sharedBatches.count == 1)
        #expect(sharedBatches[0].map(\.lastPathComponent) == ["report.pdf", "photo.png"])
    }
}

