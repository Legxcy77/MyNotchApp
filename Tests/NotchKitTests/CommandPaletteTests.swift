import Foundation
import Testing
@testable import NotchKit

@Suite struct CommandPaletteTests {
    @Test func parsesPackageJsonMakefileAndSwiftPackage() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mynotch-palette-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let pkg = #"{"scripts":{"dev":"vite","test":"vitest run"}}"#
        try Data(pkg.utf8).write(to: dir.appendingPathComponent("package.json"))

        let mk = """
        .PHONY: build clean
        build:
        \techo building
        clean:
        \trm -rf dist
        """
        try Data(mk.utf8).write(to: dir.appendingPathComponent("Makefile"))
        try Data("// swift-tools-version: 6.0".utf8).write(to: dir.appendingPathComponent("Package.swift"))

        let tasks = RepoTaskScanner.scan(repoPath: dir.path)
        #expect(tasks.contains { $0.kind == .npm && $0.command == "npm run dev" })
        #expect(tasks.contains { $0.kind == .npm && $0.command == "npm test" })
        #expect(tasks.contains { $0.kind == .make && $0.command == "make build" })
        #expect(tasks.contains { $0.kind == .make && $0.command == "make clean" })
        #expect(tasks.contains { $0.kind == .swift && $0.command == "swift test" })
    }

    @Test func fuzzyFiltersTasks() {
        let tasks = [
            RepoTask(kind: .npm, name: "test", command: "npm test", detail: "vitest"),
            RepoTask(kind: .npm, name: "build", command: "npm run build", detail: "tsc && vite build"),
            RepoTask(kind: .make, name: "deploy", command: "make deploy", detail: "rsync"),
        ]
        #expect(RepoTaskScanner.filter(tasks, query: "nbu").map(\.name) == ["build"])
        #expect(RepoTaskScanner.filter(tasks, query: "test").map(\.name) == ["test"])
        #expect(RepoTaskScanner.filter(tasks, query: "").count == 3)
    }
}

