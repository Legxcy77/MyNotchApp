import Foundation

public enum PackageEcosystem: String, Equatable, Sendable, Codable, CaseIterable {
    case npm
    case nuget
    case swiftPM = "swift_pm"
    case unity
}

public enum AdvisorySeverity: String, Equatable, Sendable, Codable, Comparable {
    case low
    case moderate
    case high
    case critical
    case unknown

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self] = [.unknown, .low, .moderate, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

public struct DependencyFinding: Equatable, Sendable, Identifiable {
    public var id: String { "\(ecosystem.rawValue):\(packageName):\(version)" }
    public var ecosystem: PackageEcosystem
    public var packageName: String
    public var version: String
    public var advisorySource: String
    public var severity: AdvisorySeverity
    public var isConfirmed: Bool
    public var checkedAt: Date

    public init(
        ecosystem: PackageEcosystem,
        packageName: String,
        version: String,
        advisorySource: String,
        severity: AdvisorySeverity,
        isConfirmed: Bool,
        checkedAt: Date = Date()
    ) {
        self.ecosystem = ecosystem
        self.packageName = packageName
        self.version = version
        self.advisorySource = advisorySource
        self.severity = severity
        self.isConfirmed = isConfirmed
        self.checkedAt = checkedAt
    }
}

/// Read-only dependency & advisory parser. Never auto-updates packages or uploads source code.
public enum DependencySecurityWatcher {
    public static func detectEcosystems(in repoRoot: URL) -> [PackageEcosystem] {
        var found: [PackageEcosystem] = []
        let fm = FileManager.default
        if fm.fileExists(atPath: repoRoot.appendingPathComponent("package.json").path) {
            found.append(.npm)
        }
        if fm.fileExists(atPath: repoRoot.appendingPathComponent("Package.swift").path) {
            found.append(.swiftPM)
        }
        if fm.fileExists(atPath: repoRoot.appendingPathComponent("Packages/manifest.json").path) {
            found.append(.unity)
        }
        if let items = try? fm.contentsOfDirectory(at: repoRoot, includingPropertiesForKeys: nil),
           items.contains(where: { $0.pathExtension == "csproj" || $0.pathExtension == "sln" }) {
            found.append(.nuget)
        }
        return found
    }

    public static func parseNpmAuditJSON(_ data: Data, now: Date = Date()) -> [DependencyFinding] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vulns = json["vulnerabilities"] as? [String: [String: Any]] else {
            return []
        }

        return vulns.compactMap { pkgName, info -> DependencyFinding? in
            let severityRaw = (info["severity"] as? String) ?? "unknown"
            let severity = AdvisorySeverity(rawValue: severityRaw.lowercased()) ?? .unknown
            let range = (info["range"] as? String) ?? "*"
            return DependencyFinding(
                ecosystem: .npm,
                packageName: pkgName,
                version: range,
                advisorySource: "npm audit",
                severity: severity,
                isConfirmed: true,
                checkedAt: now
            )
        }
        .sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.packageName < rhs.packageName
        }
    }
}

