import Foundation
import Testing
@testable import NotchKit

@Suite struct DevCockpitPhasesTests {
    @Test func phase5ServiceHealthSeparatesEngineUnavailableAndTracksDependencies() {
        let unavailable = ServiceHealthInspector.evaluate(containers: [], engineAvailability: .daemonStopped)
        #expect(unavailable.engineAvailability == .daemonStopped)
        #expect(unavailable.services.isEmpty)

        let containers = [
            DockerContainer(id: "c1", name: "redis", image: "redis:7", state: "exited", status: "Exited (137) 2 minutes ago", portsSummary: "6379"),
            DockerContainer(id: "c2", name: "api", image: "node:22", state: "running", status: "Up 5 minutes (healthy)", portsSummary: "3000")
        ]
        let summary = ServiceHealthInspector.evaluate(
            containers: containers,
            engineAvailability: .available,
            dependencyMap: ["api": ["redis"]]
        )
        #expect(summary.services.count == 2)
        #expect(summary.services[0].state == .crashed)
        #expect(summary.services[1].state == .running)
        #expect(summary.services[1].affectedDependency == "redis")
    }

    @Test func phase6CIWatchtowerParsesGitHubRunsAndStaleLiveFlag() {
        let json = """
        {
          "workflow_runs": [
            {
              "id": 9001,
              "name": "Swift CI",
              "head_branch": "main",
              "head_sha": "abcdef1234567",
              "status": "completed",
              "conclusion": "failure",
              "run_started_at": "2026-11-16T01:00:00Z",
              "updated_at": "2026-11-16T01:02:00Z",
              "html_url": "https://github.com/Legxcy77/MyNotchApp/actions/runs/9001"
            }
          ]
        }
        """
        let runs = CIWatchtowerParser.parseGitHubWorkflowRuns(Data(json.utf8), repository: "Legxcy77/MyNotchApp", isLive: false)
        #expect(runs.count == 1)
        #expect(runs[0].status == .failure)
        #expect(runs[0].commitSHA == "abcdef1")
        #expect(!runs[0].isLive)
    }

    @Test func phase7DatabaseMigrationRedactsSecretsAndDetectsPendingMigrations() throws {
        let redacted = ConnectionStringRedactor.redact("postgres://admin:TopSecret123@db.local:5432/app")
        #expect(!redacted.contains("TopSecret123"))
        #expect(redacted.contains("[REDACTED]"))

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DBMigTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let migDir = root.appendingPathComponent("migrations", isDirectory: true)
        try FileManager.default.createDirectory(at: migDir, withIntermediateDirectories: true)
        try "CREATE TABLE a(id INT);".write(to: migDir.appendingPathComponent("001_init.sql"), atomically: true, encoding: .utf8)
        try "ALTER TABLE a ADD b INT;".write(to: migDir.appendingPathComponent("002_add_b.sql"), atomically: true, encoding: .utf8)

        let report = DatabaseMigrationInspector.inspectLocalMigrations(in: root, appliedMigrations: ["001_init.sql"])
        #expect(report.availability == .available)
        #expect(report.migrationStatus == .pending(count: 1, files: ["002_add_b.sql"]))
    }

    @Test func phase8DependencyWatcherDetectsEcosystemsAndNpmAudit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DepTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{}".write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try "// swift-tools-version: 6.0".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let ecosystems = DependencySecurityWatcher.detectEcosystems(in: root)
        #expect(ecosystems.contains(.npm))
        #expect(ecosystems.contains(.swiftPM))

        let auditJSON = """
        {
          "vulnerabilities": {
            "lodash": { "severity": "high", "range": "<4.17.21" },
            "minimist": { "severity": "moderate", "range": "<1.2.6" }
          }
        }
        """
        let findings = DependencySecurityWatcher.parseNpmAuditJSON(Data(auditJSON.utf8))
        #expect(findings.count == 2)
        #expect(findings[0].packageName == "lodash")
        #expect(findings[0].severity == .high)
        #expect(findings[0].isConfirmed)
    }

    @Test func phase9EnvGuardComparesKeysWithoutLeakingValuesAndSafeMethodCheck() {
        let example = """
        PORT=3000
        DATABASE_URL=
        JWT_SECRET=changeme
        """
        let actual = """
        PORT=3000
        JWT_SECRET=super_secret_value_never_logged
        EXTRA_FLAG=true
        """
        let report = EnvGuard.compare(exampleContent: example, envContent: actual)
        #expect(report.missingKeys == ["DATABASE_URL"])
        #expect(report.extraKeys == ["EXTRA_FLAG"])
        #expect(!report.isHealthy)
        #expect(!report.missingKeys.joined().contains("super_secret_value_never_logged"))

        #expect(SafeAPIHealthCheck.isSafeMethod("GET"))
        #expect(SafeAPIHealthCheck.isSafeMethod("HEAD"))
        #expect(!SafeAPIHealthCheck.isSafeMethod("POST"))
        #expect(!SafeAPIHealthCheck.isSafeMethod("DELETE"))
    }

    @Test func phase10ReleaseReadinessNeverTreatsUnknownAsPassed() {
        // When CI or Env is unknown, must NOT report .ready
        let buildPassed = BuildTestResult(
            id: "b1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .build,
            status: .passed,
            summary: "Build succeeded"
        )
        let cleanGit = GitStatus(repoRoot: "/tmp/MyNotchApp", repoName: "MyNotchApp", branch: "main", dirtyCount: 0, ahead: 0, behind: 0)
        let partial = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildPassed,
            gitStatus: cleanGit,
            agentConflicts: [],
            ciRun: nil,
            envReport: nil
        )
        #expect(partial.status == .needsAttention)

        // When all gates explicitly pass -> .ready
        let ciPassed = CIRunRecord(id: "1", repository: "MyNotchApp", branch: "main", commitSHA: "abc", workflow: "CI", status: .success)
        let envOK = EnvGuardReport(missingKeys: [], extraKeys: [], invalidLines: [])
        let ready = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildPassed,
            gitStatus: cleanGit,
            agentConflicts: [],
            ciRun: ciPassed,
            envReport: envOK,
            securityFindings: []
        )
        #expect(ready.status == .ready)

        // When a build failed -> .blocked
        let buildFailed = BuildTestResult(
            id: "b2",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .build,
            status: .failed,
            summary: "1 error"
        )
        let blocked = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildFailed,
            gitStatus: cleanGit,
            agentConflicts: [],
            ciRun: ciPassed,
            envReport: envOK
        )
        #expect(blocked.status == .blocked)
    }

    @Test
    func reducerUpdatesReleaseReadinessAndEventBusRoutesCI() {
        var state = NotchState()
        #expect(state.releaseReadiness == nil)

        let git = GitStatus(repoRoot: "/tmp/MyNotchApp", repoName: "MyNotchApp", branch: "main", dirtyCount: 0, ahead: 0, behind: 0)
        _ = NotchReducer.reduce(&state, .gitStatusUpdated(git))
        #expect(state.releaseReadiness != nil)
        #expect(state.releaseReadiness?.status == .needsAttention || state.releaseReadiness?.status == .unknown)

        let buildInput = BuildEventInput(
            runID: "b-int-1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .test,
            phase: .finished,
            exitCode: 0,
            durationSeconds: 1.2,
            output: "Test run with 140 tests passed"
        )
        _ = NotchReducer.reduce(&state, .buildEvent(buildInput))
        _ = NotchReducer.reduce(&state, .envGuardUpdated(EnvGuardReport(missingKeys: [], extraKeys: [], invalidLines: [])))

        let router = EventBusRouter(token: "test-token")
        let ciPayload = #"{"workflow_runs":[{"id":99,"name":"CI","head_branch":"main","head_sha":"deadbeef","status":"completed","conclusion":"success"}]}"#
        let req = HTTPRequest(
            method: "POST",
            path: "/ci",
            headers: ["authorization": "Bearer test-token"],
            body: Data(ciPayload.utf8)
        )
        let res = router.handle(req)
        #expect(res.response.statusCode == 200)
        if case .ciRunsUpdated(let runs)? = res.action {
            _ = NotchReducer.reduce(&state, .ciRunsUpdated(runs))
        } else {
            Issue.record("Expected ciRunsUpdated action")
        }

        #expect(state.releaseReadiness?.status == .ready)

        // Invalid CI payload returns 400
        let badReq = HTTPRequest(
            method: "POST",
            path: "/ci",
            headers: ["authorization": "Bearer test-token"],
            body: Data("{}".utf8)
        )
        #expect(router.handle(badReq).response.statusCode == 400)
    }

    @Test
    func phase5ServiceHealthCoversAllContainerStatesAndDependencies() {
        let containers = [
            DockerContainer(id: "c1", name: "db", image: "postgres:16", state: "exited", status: "Exited (0) 2 hours ago", portsSummary: ""),
            DockerContainer(id: "c2", name: "redis", image: "redis:7", state: "exited", status: "Exited (137) 1 minute ago", portsSummary: "6379->6379"),
            DockerContainer(id: "c3", name: "worker", image: "node:22", state: "restarting", status: "Restarting (1) 5 seconds ago", portsSummary: ""),
            DockerContainer(id: "c4", name: "api", image: "node:22", state: "running", status: "Up 3 minutes (unhealthy)", portsSummary: "3000->3000"),
            DockerContainer(id: "c5", name: "web", image: "nginx", state: "running", status: "Up 3 minutes (healthy)", portsSummary: "80->80"),
            DockerContainer(id: "c6", name: "init", image: "alpine", state: "created", status: "Created", portsSummary: "")
        ]

        let summary = ServiceHealthInspector.evaluate(
            containers: containers,
            engineAvailability: .available,
            dependencyMap: ["web": ["api", "redis"]]
        )
        #expect(summary.services.count == 6)
        #expect(summary.services[0].state == .stopped)
        #expect(summary.services[1].state == .crashed)
        #expect(summary.services[2].state == .restarting)
        #expect(summary.services[3].state == .unhealthy)
        #expect(summary.services[4].state == .running)
        #expect(summary.services[4].affectedDependency == "api")
        #expect(summary.services[5].state == .stopped)
        #expect(summary.unhealthyCount == 3)

        let stoppedEngine = ServiceHealthInspector.evaluate(containers: containers, engineAvailability: .daemonStopped)
        #expect(stoppedEngine.services.isEmpty)
        #expect(stoppedEngine.engineAvailability == .daemonStopped)
    }

    @Test
    func phase6CIWatchtowerMapsAllStatusesAndRejectsInvalidJSON() {
        #expect(CIWatchtowerParser.mapStatus(status: "queued", conclusion: "") == .queued)
        #expect(CIWatchtowerParser.mapStatus(status: "waiting", conclusion: "") == .queued)
        #expect(CIWatchtowerParser.mapStatus(status: "in_progress", conclusion: "") == .inProgress)
        #expect(CIWatchtowerParser.mapStatus(status: "completed", conclusion: "timed_out") == .failure)
        #expect(CIWatchtowerParser.mapStatus(status: "completed", conclusion: "cancelled") == .cancelled)
        #expect(CIWatchtowerParser.mapStatus(status: "completed", conclusion: "skipped") == .cancelled)
        #expect(CIWatchtowerParser.mapStatus(status: "completed", conclusion: "weird") == .unknown)
        #expect(CIWatchtowerParser.mapStatus(status: "other", conclusion: "") == .unknown)

        #expect(CIWatchtowerParser.parseGitHubWorkflowRuns(Data("not json".utf8), repository: "repo").isEmpty)
    }

    @Test
    func phase7DatabaseMigrationRedactsSQLServerAndHandlesAllMigrationStates() throws {
        let sqlServer = "Server=localhost;Database=app;User Id=sa;Password=TopSecret!123;Pwd=abc;Secret=xyz"
        let redacted = ConnectionStringRedactor.redact(sqlServer)
        #expect(!redacted.contains("TopSecret!123"))
        #expect(!redacted.contains("=abc"))
        #expect(!redacted.contains("=xyz"))
        #expect(redacted.contains("[REDACTED]"))

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("db-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // No migrations folder -> .unconfigured
        let unconfigured = DatabaseMigrationInspector.inspectLocalMigrations(in: tmp, appliedMigrations: [])
        #expect(unconfigured.availability == .unconfigured)

        // With prisma/migrations
        let prismaDir = tmp.appendingPathComponent("prisma/migrations", isDirectory: true)
        try FileManager.default.createDirectory(at: prismaDir, withIntermediateDirectories: true)
        try Data().write(to: prismaDir.appendingPathComponent("20260101_init"))

        let unknownApplied = DatabaseMigrationInspector.inspectLocalMigrations(in: tmp, appliedMigrations: nil)
        #expect(unknownApplied.availability == .unknown)
        #expect(unknownApplied.migrationStatus == .unknown)

        let upToDate = DatabaseMigrationInspector.inspectLocalMigrations(in: tmp, appliedMigrations: ["20260101_init"])
        #expect(upToDate.availability == .available)
        #expect(upToDate.migrationStatus == .upToDate)
    }

    @Test
    func phase8DependencyWatcherDetectsUnityAndNugetAndSortsAuditBySeverity() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("sec-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("Packages"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try "{}".write(to: tmp.appendingPathComponent("Packages/manifest.json"), atomically: true, encoding: .utf8)
        try "<Project/>".write(to: tmp.appendingPathComponent("App.csproj"), atomically: true, encoding: .utf8)

        let ecosystems = DependencySecurityWatcher.detectEcosystems(in: tmp)
        #expect(ecosystems.contains(.unity))
        #expect(ecosystems.contains(.nuget))

        let auditJSON = """
        {
          "vulnerabilities": {
            "zlib-low": { "severity": "low", "range": "<1.0.0" },
            "alpha-crit": { "severity": "critical", "range": "<2.0.0" },
            "beta-high": { "severity": "high", "range": "*" }
          }
        }
        """
        let findings = DependencySecurityWatcher.parseNpmAuditJSON(Data(auditJSON.utf8))
        #expect(findings.map(\.packageName) == ["alpha-crit", "beta-high", "zlib-low"])
        #expect(DependencySecurityWatcher.parseNpmAuditJSON(Data("invalid".utf8)).isEmpty)
    }

    @Test
    func phase9EnvGuardHandlesExportCommentsInvalidLinesAndSafeAPIMethods() {
        let example = """
        # Database
        export DATABASE_URL=postgres://example
        API_KEY=
        """
        let env = """
        DATABASE_URL=postgres://secret
        BAD LINE WITHOUT EQUALS
        INVALID KEY=value
        EXTRA_FLAG=1
        """
        let report = EnvGuard.compare(exampleContent: example, envContent: env)
        #expect(report.missingKeys == ["API_KEY"])
        #expect(report.extraKeys == ["EXTRA_FLAG"])
        #expect(report.invalidLines == ["Line 2", "Line 3"])
        #expect(!report.isHealthy)

        #expect(SafeAPIHealthCheck.isSafeMethod("head"))
        #expect(!SafeAPIHealthCheck.isSafeMethod("PATCH"))

        let ok = SafeAPIHealthResult(url: URL(string: "http://localhost:3000/health")!, statusCode: 204, latencyMs: 12, errorMessage: nil, checkedAt: Date())
        let fail = SafeAPIHealthResult(url: URL(string: "http://localhost:3000/health")!, statusCode: 503, latencyMs: 12, errorMessage: nil, checkedAt: Date())
        let down = SafeAPIHealthResult(url: URL(string: "http://localhost:3000/health")!, statusCode: nil, latencyMs: nil, errorMessage: "Connection refused", checkedAt: Date())
        #expect(ok.isHealthy)
        #expect(!fail.isHealthy)
        #expect(!down.isHealthy)
    }

    @Test
    func phase10ReleaseReadinessCoversConfirmedConflictSecurityAndUnknownStates() {
        let buildPassed = BuildTestResult(id: "b1", project: "App", toolchain: .swift, kind: .test, status: .passed, summary: "ok")
        let cleanGit = GitStatus(repoRoot: "/tmp/App", repoName: "App", branch: "main", dirtyCount: 0, ahead: 0, behind: 0)
        let ciPassed = CIRunRecord(id: "1", repository: "App", branch: "main", commitSHA: "abc", workflow: "CI", status: .success)
        let envOK = EnvGuardReport(missingKeys: [], extraKeys: [], invalidLines: [])

        let confirmedConflict = AgentConflict(
            id: "conf-1",
            kind: .sameFileModified,
            confidence: .confirmed,
            sessions: [
                AgentSession.Key(source: "claude", session: "s1"),
                AgentSession.Key(source: "codex", session: "s2")
            ],
            filePath: "A.swift",
            title: "Same file",
            detail: "A.swift"
        )
        let blockedByConflict = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildPassed,
            gitStatus: cleanGit,
            agentConflicts: [confirmedConflict],
            ciRun: ciPassed,
            envReport: envOK
        )
        #expect(blockedByConflict.status == .blocked)

        let highFinding = DependencyFinding(
            ecosystem: .npm,
            packageName: "lodash",
            version: "<4.17.21",
            advisorySource: "npm audit",
            severity: .high,
            isConfirmed: true
        )
        let blockedBySecurity = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildPassed,
            gitStatus: cleanGit,
            agentConflicts: [],
            ciRun: ciPassed,
            envReport: envOK,
            securityFindings: [highFinding]
        )
        #expect(blockedBySecurity.status == .blocked)

        let lowFinding = DependencyFinding(
            ecosystem: .npm,
            packageName: "minimist",
            version: "<1.2.6",
            advisorySource: "npm audit",
            severity: .low,
            isConfirmed: true
        )
        let cautionBySecurity = ReleaseReadinessEvaluator.evaluate(
            latestBuild: buildPassed,
            gitStatus: cleanGit,
            agentConflicts: [],
            ciRun: ciPassed,
            envReport: envOK,
            securityFindings: [lowFinding]
        )
        #expect(cautionBySecurity.status == .needsAttention)
    }

    @Test
    func collapsedEarsExpandOnCockpitSignalsAndStayHiddenWhenIdle() {
        var state = NotchState()
        #expect(!state.showsEars)

        let dirtyGit = GitStatus(repoRoot: "/tmp/keystay", repoName: "keystay", branch: "main", dirtyCount: 2, ahead: 0, behind: 0)
        _ = NotchReducer.reduce(&state, .gitStatusUpdated(dirtyGit))
        #expect(state.showsEars)

        let cleanGit = GitStatus(repoRoot: "/tmp/keystay", repoName: "keystay", branch: "main", dirtyCount: 0, ahead: 0, behind: 0)
        _ = NotchReducer.reduce(&state, .gitStatusUpdated(cleanGit))
        #expect(!state.showsEars)
    }
}
