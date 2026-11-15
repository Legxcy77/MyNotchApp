import Foundation

public struct RepoTask: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case npm, make, dotnet, swift
    }

    public var id: String { "\(kind.rawValue):\(name)" }
    public var kind: Kind
    public var name: String
    public var command: String
    public var detail: String

    public init(kind: Kind, name: String, command: String, detail: String) {
        self.kind = kind
        self.name = name
        self.command = command
        self.detail = detail
    }
}

public enum RepoTaskScanner {
    public static func scan(repoPath: String) -> [RepoTask] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: repoPath, isDirectory: true)
        var tasks: [RepoTask] = []

        // 1. package.json
        let pkgURL = root.appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: pkgURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = obj["scripts"] as? [String: String] {
            for name in scripts.keys.sorted() {
                let cmd = name == "test" ? "npm test" : "npm run \(name)"
                tasks.append(RepoTask(kind: .npm, name: name, command: cmd, detail: scripts[name] ?? ""))
            }
        }

        // 2. Makefile
        let mkURL = root.appendingPathComponent("Makefile")
        if let mk = try? String(contentsOf: mkURL, encoding: .utf8) {
            for line in mk.split(whereSeparator: \.isNewline) {
                let s = String(line)
                guard !s.hasPrefix("\t"), !s.hasPrefix(" "), !s.hasPrefix("#"), !s.hasPrefix(".") else { continue }
                guard let colon = s.firstIndex(of: ":") else { continue }
                let target = s[..<colon].trimmingCharacters(in: .whitespaces)
                guard !target.isEmpty, !target.contains(" "), !target.contains("=") else { continue }
                tasks.append(RepoTask(kind: .make, name: target, command: "make \(target)", detail: "Makefile target"))
            }
        }

        // 3. .NET (*.csproj / *.sln)
        if let entries = try? fm.contentsOfDirectory(atPath: repoPath),
           entries.contains(where: { $0.hasSuffix(".csproj") || $0.hasSuffix(".sln") }) {
            tasks.append(RepoTask(kind: .dotnet, name: "build", command: "dotnet build", detail: ".NET build"))
            tasks.append(RepoTask(kind: .dotnet, name: "test", command: "dotnet test", detail: ".NET test"))
            tasks.append(RepoTask(kind: .dotnet, name: "run", command: "dotnet run", detail: ".NET run"))
        }

        // 4. Swift Package
        if fm.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            tasks.append(RepoTask(kind: .swift, name: "build", command: "swift build", detail: "SwiftPM build"))
            tasks.append(RepoTask(kind: .swift, name: "test", command: "swift test", detail: "SwiftPM test"))
        }

        return tasks
    }

    public static func filter(_ tasks: [RepoTask], query: String) -> [RepoTask] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tasks }
        return tasks.filter { task in
            let haystack = "\(task.command) \(task.name) \(task.detail)".lowercased()
            if haystack.contains(q) { return true }
            return isSubsequence(q, in: haystack)
        }
    }

    private static func isSubsequence(_ needle: String, in haystack: String) -> Bool {
        var it = needle.makeIterator()
        guard var current = it.next() else { return true }
        for ch in haystack where ch == current {
            guard let next = it.next() else { return true }
            current = next
        }
        return false
    }
}

