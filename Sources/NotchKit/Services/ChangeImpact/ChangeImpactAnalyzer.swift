import Foundation

public enum ImpactDependencyKind: String, Equatable, Sendable, Codable {
    case direct
    case inferred
}

public enum ChangeRiskLevel: String, Equatable, Sendable, Codable, Comparable {
    case low
    case medium
    case high

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self] = [.low, .medium, .high]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

public struct ImpactedItem: Equatable, Sendable, Identifiable {
    public var id: String { "\(kind.rawValue):\(path)" }
    public var path: String
    public var kind: ImpactDependencyKind
    public var reason: String

    public init(path: String, kind: ImpactDependencyKind, reason: String) {
        self.path = path
        self.kind = kind
        self.reason = reason
    }
}

public struct SuggestedTest: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var path: String
    public var reason: String

    public init(name: String, path: String, reason: String) {
        self.name = name
        self.path = path
        self.reason = reason
    }
}

public struct ChangeImpactReport: Equatable, Sendable {
    public var changedFiles: [String]
    public var impacts: [ImpactedItem]
    public var suggestedTests: [SuggestedTest]
    public var riskLevel: ChangeRiskLevel
    public var analyzedAt: Date

    public init(
        changedFiles: [String],
        impacts: [ImpactedItem],
        suggestedTests: [SuggestedTest],
        riskLevel: ChangeRiskLevel,
        analyzedAt: Date = Date()
    ) {
        self.changedFiles = changedFiles
        self.impacts = impacts
        self.suggestedTests = suggestedTests
        self.riskLevel = riskLevel
        self.analyzedAt = analyzedAt
    }
}

/// Pure deterministic analyzer for git working tree changes.
/// Separates direct manifest/config impacts from inferred code/test references without running tests or invoking LLMs.
public enum ChangeImpactAnalyzer {
    private static let highRiskFilenames: Set<String> = [
        "package.swift", "package.resolved", "package.json", "package-lock.json",
        "pnpm-lock.yaml", "yarn.lock", "dockerfile", "docker-compose.yml", "docker-compose.yaml"
    ]

    public static func analyze(
        changedFiles: [String],
        repoRoot: URL?,
        now: Date = Date()
    ) -> ChangeImpactReport {
        let uniqueFiles = Array(Set(changedFiles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        guard !uniqueFiles.isEmpty else {
            return ChangeImpactReport(changedFiles: [], impacts: [], suggestedTests: [], riskLevel: .low, analyzedAt: now)
        }

        var impacts: [ImpactedItem] = []
        var suggestedTests: [SuggestedTest] = []
        var risk: ChangeRiskLevel = uniqueFiles.count >= 12 ? .medium : .low

        for file in uniqueFiles {
            let lower = file.lowercased()
            let base = (file as NSString).lastPathComponent
            let baseLower = base.lowercased()

            if highRiskFilenames.contains(baseLower) || baseLower.hasSuffix(".csproj") || baseLower.hasSuffix(".sln") {
                risk = .high
                impacts.append(ImpactedItem(path: file, kind: .direct, reason: "Build/dependency manifest modified"))
            } else if lower.contains("migration") || lower.hasSuffix(".sql") || baseLower.hasPrefix(".env") {
                risk = .high
                impacts.append(ImpactedItem(path: file, kind: .direct, reason: "Schema or environment configuration modified"))
            } else if lower.contains("auth") || lower.contains("security") || lower.contains("permission") {
                risk = max(risk, .medium)
                impacts.append(ImpactedItem(path: file, kind: .direct, reason: "Security/auth module modified"))
            }
        }

        if let repoRoot {
            let allRepoFiles = collectSourceAndTestFiles(under: repoRoot)
            let changedStems = uniqueFiles.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
                .filter { $0.count >= 3 }

            for candidateURL in allRepoFiles {
                let relPath = candidateURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                if uniqueFiles.contains(relPath) { continue }
                let fileName = candidateURL.lastPathComponent
                let lowerName = fileName.lowercased()
                let isTestFile = lowerName.contains("test") || lowerName.contains("spec")

                for stem in changedStems {
                    if isTestFile && lowerName.contains(stem.lowercased()) {
                        if !suggestedTests.contains(where: { $0.path == relPath }) {
                            suggestedTests.append(SuggestedTest(
                                name: fileName,
                                path: relPath,
                                reason: "Matches changed symbol '\(stem)' (suggested)"
                            ))
                        }
                    } else if !isTestFile,
                              let content = try? String(contentsOf: candidateURL, encoding: .utf8),
                              content.contains(stem) {
                        if !impacts.contains(where: { $0.path == relPath }) {
                            impacts.append(ImpactedItem(
                                path: relPath,
                                kind: .inferred,
                                reason: "References '\(stem)'"
                            ))
                        }
                    }
                }
            }
        }

        return ChangeImpactReport(
            changedFiles: uniqueFiles,
            impacts: impacts.sorted { $0.path < $1.path },
            suggestedTests: suggestedTests.sorted { $0.name < $1.name },
            riskLevel: risk,
            analyzedAt: now
        )
    }

    private static func collectSourceAndTestFiles(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        let allowedExts: Set<String> = ["swift", "ts", "tsx", "js", "jsx", "cs"]
        while let item = enumerator.nextObject() as? URL {
            let path = item.path
            if path.contains("/.build/") || path.contains("/node_modules/") || path.contains("/bin/") || path.contains("/obj/") {
                continue
            }
            if allowedExts.contains(item.pathExtension.lowercased()) {
                urls.append(item)
                if urls.count >= 400 { break }
            }
        }
        return urls
    }
}

