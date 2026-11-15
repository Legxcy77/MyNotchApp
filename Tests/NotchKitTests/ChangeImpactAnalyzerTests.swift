import Foundation
import Testing
@testable import NotchKit

@Suite struct ChangeImpactAnalyzerTests {
    @Test func analyzesChangedFilesAndSuggestsMatchingTestsWithReasons() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImpactTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let srcDir = root.appendingPathComponent("Sources/Auth", isDirectory: true)
        let testDir = root.appendingPathComponent("Tests/AuthTests", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        try "final class UserService {}".write(to: srcDir.appendingPathComponent("UserService.swift"), atomically: true, encoding: .utf8)
        try "import Auth\nlet s = UserService()".write(to: srcDir.appendingPathComponent("LoginController.swift"), atomically: true, encoding: .utf8)
        try "final class UserServiceTests {}".write(to: testDir.appendingPathComponent("UserServiceTests.swift"), atomically: true, encoding: .utf8)

        let report = ChangeImpactAnalyzer.analyze(
            changedFiles: ["Sources/Auth/UserService.swift", "Package.swift"],
            repoRoot: root
        )

        #expect(report.changedFiles.count == 2)
        #expect(report.riskLevel == .high) // Package.swift is a build/dependency manifest
        #expect(report.impacts.contains { $0.path == "Package.swift" && $0.kind == .direct })
        #expect(report.impacts.contains { $0.path.contains("LoginController.swift") && $0.kind == .inferred })
        #expect(report.suggestedTests.contains { $0.name == "UserServiceTests.swift" && !$0.reason.isEmpty })
    }

    @Test func handlesEmptyChangesCleanly() {
        let report = ChangeImpactAnalyzer.analyze(changedFiles: [], repoRoot: nil)
        #expect(report.changedFiles.isEmpty)
        #expect(report.suggestedTests.isEmpty)
        #expect(report.riskLevel == .low)
    }
}

