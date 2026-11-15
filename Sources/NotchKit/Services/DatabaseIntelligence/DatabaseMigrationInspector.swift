import Foundation

public enum DatabaseAvailability: Equatable, Sendable {
    case available
    case connectionFailed(reason: String)
    case unconfigured
    case unknown
}

public enum MigrationStatus: Equatable, Sendable {
    case upToDate
    case pending(count: Int, files: [String])
    case failed(reason: String)
    case schemaDrift(detail: String)
    case unknown
}

public struct DatabaseHealthReport: Equatable, Sendable {
    public var engine: String
    public var environment: String
    public var availability: DatabaseAvailability
    public var migrationStatus: MigrationStatus
    public var lastCheckedAt: Date

    public init(
        engine: String,
        environment: String,
        availability: DatabaseAvailability,
        migrationStatus: MigrationStatus,
        lastCheckedAt: Date = Date()
    ) {
        self.engine = engine
        self.environment = environment
        self.availability = availability
        self.migrationStatus = migrationStatus
        self.lastCheckedAt = lastCheckedAt
    }
}

public enum ConnectionStringRedactor {
    public static func redact(_ raw: String) -> String {
        var result = raw
        let patterns = [
            (#"(://[^:\s/]+:)[^@\s]+(@)"#, "$1[REDACTED]$2"),
            (#"((?:Password|Pwd|Secret)\s*=\s*)[^;\s\n]+"#, "$1[REDACTED]")
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        return result
    }
}

/// Read-only database migration inspector. Never runs migrations or mutates schema.
public enum DatabaseMigrationInspector {
    public static func inspectLocalMigrations(
        in repoRoot: URL,
        appliedMigrations: Set<String>?,
        environment: String = "local",
        now: Date = Date()
    ) -> DatabaseHealthReport {
        let candidateDirs = [
            repoRoot.appendingPathComponent("migrations", isDirectory: true),
            repoRoot.appendingPathComponent("Migrations", isDirectory: true),
            repoRoot.appendingPathComponent("prisma/migrations", isDirectory: true),
            repoRoot.appendingPathComponent("supabase/migrations", isDirectory: true)
        ]

        guard let migrationDir = candidateDirs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return DatabaseHealthReport(
                engine: "Unknown",
                environment: environment,
                availability: .unconfigured,
                migrationStatus: .unknown,
                lastCheckedAt: now
            )
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: migrationDir, includingPropertiesForKeys: nil))?
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix(".") }
            .sorted() ?? []

        guard let appliedMigrations else {
            return DatabaseHealthReport(
                engine: "SQL",
                environment: environment,
                availability: .unknown,
                migrationStatus: .unknown,
                lastCheckedAt: now
            )
        }

        let pending = files.filter { !appliedMigrations.contains($0) }
        let status: MigrationStatus = pending.isEmpty ? .upToDate : .pending(count: pending.count, files: pending)
        return DatabaseHealthReport(
            engine: "SQL",
            environment: environment,
            availability: .available,
            migrationStatus: status,
            lastCheckedAt: now
        )
    }
}

