import Foundation
import Testing
@testable import NotchKit

@Suite struct BuildTestIntelligenceTests {
    @Test func parsesSwiftCompilerErrorAndLocation() {
        let output = """
        Building for debugging...
        /Users/dev/App/Sources/Main.swift:42:15: error: cannot find 'missingSymbol' in scope
        /Users/dev/App/Sources/Other.swift:10:1: warning: unused variable 'x'
        error: fatalError
        """

        let parsed = BuildOutputParser.parse(
            output: output,
            toolchain: .swift,
            kind: .build,
            exitCode: 1
        )

        #expect(parsed.status == .failed)
        #expect(parsed.errorCount >= 1)
        #expect(parsed.primaryLocation == BuildSourceLocation(
            file: "/Users/dev/App/Sources/Main.swift",
            line: 42,
            column: 15
        ))
        #expect(parsed.summary.contains("cannot find 'missingSymbol' in scope"))
    }

    @Test func parsesTypeScriptAndVitestFailures() {
        let tscOutput = """
        src/api/client.ts(18,7): error TS2322: Type 'number' is not assignable to type 'string'.
        src/api/auth.ts:44:12 - error TS2345: Argument of type 'null' is not assignable.
        """
        let tscParsed = BuildOutputParser.parse(
            output: tscOutput,
            toolchain: .nodeTypeScript,
            kind: .build,
            exitCode: 2
        )
        #expect(tscParsed.status == .failed)
        #expect(tscParsed.errorCount == 2)
        #expect(tscParsed.primaryLocation == BuildSourceLocation(file: "src/api/client.ts", line: 18, column: 7))

        let vitestJSON = """
        {
          "numFailedTests": 2,
          "numPassedTests": 14,
          "testResults": [
            {
              "name": "/repo/src/cart.test.ts",
              "assertionResults": [
                { "fullName": "Cart calculates discount", "status": "failed" },
                { "fullName": "Cart rejects negative qty", "status": "failed" },
                { "fullName": "Cart adds item", "status": "passed" }
              ]
            }
          ]
        }
        """
        let vitestParsed = BuildOutputParser.parse(
            output: vitestJSON,
            toolchain: .nodeTypeScript,
            kind: .test,
            exitCode: 1
        )
        #expect(vitestParsed.status == .failed)
        #expect(vitestParsed.failedTestCount == 2)
        #expect(vitestParsed.failedTestNames == ["Cart calculates discount", "Cart rejects negative qty"])
        #expect(vitestParsed.primaryLocation?.file == "/repo/src/cart.test.ts")
    }

    @Test func parsesDotnetBuildAndTestFailures() {
        let dotnetBuildOutput = """
          Determining projects to restore...
        /repo/Api/Controllers/OrdersController.cs(27,21): error CS0103: The name 'orderId' does not exist in the current context [/repo/Api/Api.csproj]
        """
        let buildParsed = BuildOutputParser.parse(
            output: dotnetBuildOutput,
            toolchain: .dotnet,
            kind: .build,
            exitCode: 1
        )
        #expect(buildParsed.status == .failed)
        #expect(buildParsed.errorCount == 1)
        #expect(buildParsed.primaryLocation == BuildSourceLocation(
            file: "/repo/Api/Controllers/OrdersController.cs",
            line: 27,
            column: 21
        ))

        let dotnetTestOutput = """
          Failed Api.Tests.OrderTests.RejectsExpiredCoupon [12 ms]
          Failed Api.Tests.OrderTests.AppliesTax [4 ms]
        Failed!  - Failed:     2, Passed:    18, Skipped:     0, Total:    20
        """
        let testParsed = BuildOutputParser.parse(
            output: dotnetTestOutput,
            toolchain: .dotnet,
            kind: .test,
            exitCode: 1
        )
        #expect(testParsed.status == .failed)
        #expect(testParsed.failedTestCount == 2)
        #expect(testParsed.failedTestNames == [
            "Api.Tests.OrderTests.RejectsExpiredCoupon",
            "Api.Tests.OrderTests.AppliesTax"
        ])
    }

    @Test func correlatorMergesLifecycleDeduplicatesAndHandlesCancellation() {
        var correlator = BuildEventCorrelator()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 1_002)
        let t2 = Date(timeIntervalSince1970: 1_005)

        let started = correlator.ingest(BuildEventInput(
            runID: "run-1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .test,
            phase: .started,
            timestamp: t0
        ))
        #expect(started?.status == .running)
        #expect(started?.project == "MyNotchApp")

        let diag = correlator.ingest(BuildEventInput(
            runID: "run-1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .test,
            phase: .diagnostic,
            output: "/repo/Sources/Foo.swift:12:4: error: type mismatch",
            timestamp: t1
        ))
        #expect(diag?.primaryLocation?.file == "/repo/Sources/Foo.swift")
        #expect(diag?.primaryLocation?.line == 12)

        let finished = correlator.ingest(BuildEventInput(
            runID: "run-1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .test,
            phase: .finished,
            exitCode: 1,
            timestamp: t2
        ))
        #expect(finished?.status == .failed)
        #expect(finished?.exitCode == 1)
        #expect(finished?.durationSeconds == 5)
        #expect(finished?.primaryLocation?.file == "/repo/Sources/Foo.swift")

        // Duplicate finish event with identical state is suppressed
        let duplicate = correlator.ingest(BuildEventInput(
            runID: "run-1",
            project: "MyNotchApp",
            toolchain: .swift,
            kind: .test,
            phase: .finished,
            exitCode: 1,
            timestamp: t2
        ))
        #expect(duplicate == nil)

        // Cancellation path
        let cancelled = correlator.ingest(BuildEventInput(
            runID: "run-2",
            project: "WebApp",
            toolchain: .nodeTypeScript,
            kind: .build,
            phase: .cancelled,
            timestamp: t2
        ))
        #expect(cancelled?.status == .cancelled)
        #expect(cancelled?.project == "WebApp")

        // Malformed / missing exitCode finish falls back to .unknown
        let malformed = correlator.ingest(BuildEventInput(
            runID: "run-3",
            project: "UnknownProj",
            toolchain: .generic,
            kind: .build,
            phase: .finished,
            exitCode: nil,
            output: "   \n  ",
            timestamp: t2
        ))
        #expect(malformed?.status == .unknown)
    }

    @Test @MainActor func eventBusRouterDrivesNotchStoreAndStateEndToEnd() {
        let router = EventBusRouter(token: "secret-token")
        let store = NotchStore()

        func postBuild(_ json: String) -> EventBusResult {
            let req = HTTPRequest(
                method: "POST",
                path: "/build",
                headers: ["authorization": "Bearer secret-token", "content-type": "application/json"],
                body: Data(json.utf8)
            )
            return router.handle(req)
        }

        // 1. Malformed payload returns 400 and produces no action
        let bad = postBuild(#"{"project":"","phase":"invalid"}"#)
        #expect(bad.response.statusCode == 400)
        #expect(bad.action == nil)

        // 2. Happy path: started -> finished (exitCode 0)
        let started = postBuild(#"{"runId":"r1","project":"BackendAPI","toolchain":"dotnet","kind":"build","phase":"started"}"#)
        #expect(started.response.statusCode == 200)
        if case .buildEvent(let input) = started.action {
            store.send(.buildEvent(input))
        } else {
            Issue.record("Expected buildEvent action")
        }
        #expect(store.state.latestBuildResult?.status == .running)
        #expect(store.state.activeToast == nil)

        let passed = postBuild(#"{"runId":"r1","project":"BackendAPI","toolchain":"dotnet","kind":"build","phase":"finished","exitCode":0,"durationSeconds":1.8}"#)
        #expect(passed.response.statusCode == 200)
        if case .buildEvent(let input) = passed.action {
            store.send(.buildEvent(input))
        }
        #expect(store.state.latestBuildResult?.status == .passed)
        #expect(store.state.activeToast?.tint == .success)

        // 3. Failure path: Swift compiler error populates primaryLocation & failure toast
        let failed = postBuild(#"{"runId":"r2","project":"MyNotchApp","toolchain":"swift","kind":"build","phase":"finished","exitCode":1,"output":"/repo/Sources/App.swift:99:8: error: missing return"}"#)
        #expect(failed.response.statusCode == 200)
        if case .buildEvent(let input) = failed.action {
            store.send(.buildEvent(input))
        }
        #expect(store.state.latestBuildResult?.status == .failed)
        #expect(store.state.latestBuildResult?.primaryLocation == BuildSourceLocation(file: "/repo/Sources/App.swift", line: 99, column: 8))
        #expect(store.state.activeToast?.tint == .failure)
        #expect(store.state.activeToast?.errorLog != nil)
    }
}
