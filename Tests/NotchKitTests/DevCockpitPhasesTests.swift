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
    }
}
