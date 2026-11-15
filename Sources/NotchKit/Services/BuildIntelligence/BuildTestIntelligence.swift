import Foundation

public enum DeveloperToolchain: String, Equatable, Sendable, Codable, CaseIterable {
    case swift
    case nodeTypeScript = "node_ts"
    case dotnet
    case generic

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .nodeTypeScript: return "TS / Node"
        case .dotnet: return ".NET"
        case .generic: return "Build"
        }
    }
}

public enum BuildRunKind: String, Equatable, Sendable, Codable, CaseIterable {
    case build
    case test
}

public enum BuildRunStatus: String, Equatable, Sendable, Codable, CaseIterable {
    case running
    case passed
    case failed
    case cancelled
    case unknown
}

public struct BuildSourceLocation: Equatable, Hashable, Sendable, Codable {
    public var file: String
    public var line: Int
    public var column: Int?

    public init(file: String, line: Int, column: Int? = nil) {
        self.file = file
        self.line = line
        self.column = column
    }

    public var displayString: String {
        let filename = (file as NSString).lastPathComponent
        if let column {
            return "\(filename):\(line):\(column)"
        }
        return "\(filename):\(line)"
    }
}

public struct BuildTestResult: Equatable, Sendable, Codable, Identifiable {
    public var id: String
    public var project: String
    public var toolchain: DeveloperToolchain
    public var kind: BuildRunKind
    public var status: BuildRunStatus
    public var exitCode: Int32?
    public var durationSeconds: Double?
    public var errorCount: Int
    public var failedTestCount: Int
    public var failedTestNames: [String]
    public var primaryLocation: BuildSourceLocation?
    public var summary: String
    public var rawLogSnippet: String?
    public var updatedAt: Date

    public init(
        id: String,
        project: String,
        toolchain: DeveloperToolchain,
        kind: BuildRunKind,
        status: BuildRunStatus,
        exitCode: Int32? = nil,
        durationSeconds: Double? = nil,
        errorCount: Int = 0,
        failedTestCount: Int = 0,
        failedTestNames: [String] = [],
        primaryLocation: BuildSourceLocation? = nil,
        summary: String,
        rawLogSnippet: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.project = project
        self.toolchain = toolchain
        self.kind = kind
        self.status = status
        self.exitCode = exitCode
        self.durationSeconds = durationSeconds
        self.errorCount = errorCount
        self.failedTestCount = failedTestCount
        self.failedTestNames = failedTestNames
        self.primaryLocation = primaryLocation
        self.summary = summary
        self.rawLogSnippet = rawLogSnippet
        self.updatedAt = updatedAt
    }

    public var toastKey: String {
        "build:\(id)"
    }
}

public struct BuildEventInput: Equatable, Sendable, Codable {
    public enum Phase: String, Equatable, Sendable, Codable {
        case started
        case diagnostic
        case finished
        case cancelled
    }

    public var runID: String?
    public var project: String
    public var toolchain: DeveloperToolchain?
    public var kind: BuildRunKind
    public var phase: Phase
    public var exitCode: Int32?
    public var durationSeconds: Double?
    public var output: String?
    public var timestamp: Date

    public init(
        runID: String? = nil,
        project: String,
        toolchain: DeveloperToolchain? = nil,
        kind: BuildRunKind = .build,
        phase: Phase,
        exitCode: Int32? = nil,
        durationSeconds: Double? = nil,
        output: String? = nil,
        timestamp: Date = Date()
    ) {
        self.runID = runID
        self.project = project
        self.toolchain = toolchain
        self.kind = kind
        self.phase = phase
        self.exitCode = exitCode
        self.durationSeconds = durationSeconds
        self.output = output
        self.timestamp = timestamp
    }
}

public struct ParsedBuildOutput: Equatable, Sendable {
    public var status: BuildRunStatus
    public var errorCount: Int
    public var failedTestCount: Int
    public var failedTestNames: [String]
    public var primaryLocation: BuildSourceLocation?
    public var summary: String
}

public enum BuildOutputParser {
    public static func parse(
        output: String,
        toolchain: DeveloperToolchain,
        kind: BuildRunKind,
        exitCode: Int32?
    ) -> ParsedBuildOutput {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        switch toolchain {
        case .swift:
            return parseSwift(trimmed, kind: kind, exitCode: exitCode)
        case .nodeTypeScript:
            return parseNodeTypeScript(trimmed, kind: kind, exitCode: exitCode)
        case .dotnet:
            return parseDotnet(trimmed, kind: kind, exitCode: exitCode)
        case .generic:
            return parseGeneric(trimmed, kind: kind, exitCode: exitCode)
        }
    }

    // MARK: - Swift (`swift build` / `swift test`)

    private static func parseSwift(_ output: String, kind: BuildRunKind, exitCode: Int32?) -> ParsedBuildOutput {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        var locations: [BuildSourceLocation] = []
        var firstErrorMessage: String?
        var errorCount = 0
        var failedTestNames: [String] = []
        var failedTestCount = 0

        // Example: /path/Main.swift:42:15: error: cannot find 'foo' in scope
        let compilerRegex = try? NSRegularExpression(pattern: #"^(.+\.swift):(\d+):(?:(\d+):)?\s*error:\s*(.+)$"#)
        // Example: Test "myTest()" failed or Test Case '-[Suite testName]' failed
        let swiftTestingFailRegex = try? NSRegularExpression(pattern: #"Test\s+\"([^\"]+)\"\s+failed"#)
        let xcTestFailRegex = try? NSRegularExpression(pattern: #"Test Case\s+'([^']+)'\s+failed"#)
        let swiftTestingSummaryRegex = try? NSRegularExpression(pattern: #"Test run with \d+ tests? failed.*?with (\d+) issues?"#)

        for line in lines {
            if let match = firstMatch(compilerRegex, in: line) {
                errorCount += 1
                let file = group(match, at: 1, in: line) ?? ""
                let lineNo = Int(group(match, at: 2, in: line) ?? "") ?? 1
                let colNo = Int(group(match, at: 3, in: line) ?? "")
                let msg = group(match, at: 4, in: line) ?? "Compiler error"
                if locations.isEmpty && !file.isEmpty {
                    locations.append(BuildSourceLocation(file: file, line: lineNo, column: colNo))
                }
                if firstErrorMessage == nil {
                    firstErrorMessage = msg
                }
            } else if let match = firstMatch(swiftTestingFailRegex, in: line),
                      let name = group(match, at: 1, in: line) {
                failedTestNames.append(name)
            } else if let match = firstMatch(xcTestFailRegex, in: line),
                      let name = group(match, at: 1, in: line) {
                failedTestNames.append(name)
            } else if let match = firstMatch(swiftTestingSummaryRegex, in: line),
                      let countStr = group(match, at: 1, in: line),
                      let count = Int(countStr) {
                failedTestCount = max(failedTestCount, count)
            }
        }

        failedTestCount = max(failedTestCount, failedTestNames.count)
        let status = resolveStatus(
            exitCode: exitCode,
            hasFailures: errorCount > 0 || failedTestCount > 0,
            hasOutput: !output.isEmpty
        )
        let summary = buildSummary(
            status: status,
            kind: kind,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            firstMessage: firstErrorMessage ?? failedTestNames.first
        )
        return ParsedBuildOutput(
            status: status,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            failedTestNames: failedTestNames,
            primaryLocation: locations.first,
            summary: summary
        )
    }

    // MARK: - TypeScript / Node (`tsc`, `vitest`, `jest`)

    private static func parseNodeTypeScript(_ output: String, kind: BuildRunKind, exitCode: Int32?) -> ParsedBuildOutput {
        // 1. Structured JSON from `vitest --reporter=json` or `jest --json`
        if output.first == "{", let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let numFailed = (json["numFailedTests"] as? Int) ?? 0
            var failedNames: [String] = []
            var firstFile: String?

            if let suites = json["testResults"] as? [[String: Any]] {
                for suite in suites {
                    let suiteName = suite["name"] as? String
                    if let assertions = suite["assertionResults"] as? [[String: Any]] {
                        for assertion in assertions where (assertion["status"] as? String) == "failed" {
                            if firstFile == nil { firstFile = suiteName }
                            if let fullName = assertion["fullName"] as? String ?? assertion["title"] as? String {
                                failedNames.append(fullName)
                            }
                        }
                    }
                }
            }

            let effectiveFailed = max(numFailed, failedNames.count)
            let status = resolveStatus(exitCode: exitCode, hasFailures: effectiveFailed > 0, hasOutput: true)
            let location = firstFile.map { BuildSourceLocation(file: $0, line: 1) }
            let summary = buildSummary(
                status: status,
                kind: .test,
                errorCount: 0,
                failedTestCount: effectiveFailed,
                firstMessage: failedNames.first
            )
            return ParsedBuildOutput(
                status: status,
                errorCount: 0,
                failedTestCount: effectiveFailed,
                failedTestNames: failedNames,
                primaryLocation: location,
                summary: summary
            )
        }

        // 2. Text output from `tsc` or text test runners
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        var location: BuildSourceLocation?
        var firstMessage: String?
        var errorCount = 0
        var failedTestCount = 0
        var failedNames: [String] = []

        // tsc paren format: src/file.ts(18,7): error TS2322: message
        let tscParenRegex = try? NSRegularExpression(pattern: #"^(.+?)\((\d+),(\d+)\):\s*error\s+(TS\d+:\s*.+)$"#)
        // tsc colon format: src/file.ts:44:12 - error TS2345: message
        let tscColonRegex = try? NSRegularExpression(pattern: #"^(.+?):(\d+):(\d+)\s*-\s*error\s+(TS\d+:\s*.+)$"#)
        // Jest/Vitest bullet failure: ● test name
        let bulletRegex = try? NSRegularExpression(pattern: #"^\s*[●×]\s+(.+)$"#)
        // Jest/Vitest summary: Tests: 2 failed
        let testsSummaryRegex = try? NSRegularExpression(pattern: #"Tests:\s+(\d+)\s+failed"#)

        for line in lines {
            if let match = firstMatch(tscParenRegex, in: line) ?? firstMatch(tscColonRegex, in: line) {
                errorCount += 1
                if location == nil,
                   let file = group(match, at: 1, in: line),
                   let lineNo = Int(group(match, at: 2, in: line) ?? "") {
                    let colNo = Int(group(match, at: 3, in: line) ?? "")
                    location = BuildSourceLocation(file: file, line: lineNo, column: colNo)
                }
                if firstMessage == nil {
                    firstMessage = group(match, at: 4, in: line)
                }
            } else if let match = firstMatch(bulletRegex, in: line),
                      let name = group(match, at: 1, in: line) {
                failedNames.append(name)
            } else if let match = firstMatch(testsSummaryRegex, in: line),
                      let count = Int(group(match, at: 1, in: line) ?? "") {
                failedTestCount = max(failedTestCount, count)
            }
        }

        failedTestCount = max(failedTestCount, failedNames.count)
        let status = resolveStatus(
            exitCode: exitCode,
            hasFailures: errorCount > 0 || failedTestCount > 0,
            hasOutput: !output.isEmpty
        )
        let summary = buildSummary(
            status: status,
            kind: kind,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            firstMessage: firstMessage ?? failedNames.first
        )
        return ParsedBuildOutput(
            status: status,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            failedTestNames: failedNames,
            primaryLocation: location,
            summary: summary
        )
    }

    // MARK: - .NET (`dotnet build` / `dotnet test`)

    private static func parseDotnet(_ output: String, kind: BuildRunKind, exitCode: Int32?) -> ParsedBuildOutput {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        var location: BuildSourceLocation?
        var firstMessage: String?
        var errorCount = 0
        var failedTestCount = 0
        var failedNames: [String] = []

        // MSBuild: /path/File.cs(27,21): error CS0103: message [/path/Proj.csproj]
        let msbuildRegex = try? NSRegularExpression(pattern: #"^\s*(.+?\.(?:cs|fs|vb))\((\d+),(\d+)\):\s*error\s+([A-Z]+\d+:\s*.+?)(?:\s+\[.+\])?$"#)
        // dotnet test failed test line:   Failed Api.Tests.OrderTests.RejectsExpiredCoupon [12 ms]
        let failedTestRegex = try? NSRegularExpression(pattern: #"^\s*Failed\s+([^\s\[]+)"#)
        // dotnet test summary: Failed!  - Failed:     2, Passed:    18
        let summaryRegex = try? NSRegularExpression(pattern: #"Failed:\s*(\d+),\s*Passed:\s*\d+"#)

        for line in lines {
            if let match = firstMatch(msbuildRegex, in: line) {
                errorCount += 1
                if location == nil,
                   let file = group(match, at: 1, in: line),
                   let lineNo = Int(group(match, at: 2, in: line) ?? "") {
                    let colNo = Int(group(match, at: 3, in: line) ?? "")
                    location = BuildSourceLocation(file: file, line: lineNo, column: colNo)
                }
                if firstMessage == nil {
                    firstMessage = group(match, at: 4, in: line)
                }
            } else if let match = firstMatch(failedTestRegex, in: line),
                      let name = group(match, at: 1, in: line),
                      !name.hasPrefix("-") {
                failedNames.append(name)
            } else if let match = firstMatch(summaryRegex, in: line),
                      let count = Int(group(match, at: 1, in: line) ?? "") {
                failedTestCount = max(failedTestCount, count)
            }
        }

        failedTestCount = max(failedTestCount, failedNames.count)
        let status = resolveStatus(
            exitCode: exitCode,
            hasFailures: errorCount > 0 || failedTestCount > 0,
            hasOutput: !output.isEmpty
        )
        let summary = buildSummary(
            status: status,
            kind: kind,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            firstMessage: firstMessage ?? failedNames.first
        )
        return ParsedBuildOutput(
            status: status,
            errorCount: errorCount,
            failedTestCount: failedTestCount,
            failedTestNames: failedNames,
            primaryLocation: location,
            summary: summary
        )
    }

    // MARK: - Generic fallback

    private static func parseGeneric(_ output: String, kind: BuildRunKind, exitCode: Int32?) -> ParsedBuildOutput {
        let lines = output.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        let firstErrorLine = lines.first { $0.localizedCaseInsensitiveContains("error") || $0.localizedCaseInsensitiveContains("failed") }
        let status = resolveStatus(exitCode: exitCode, hasFailures: firstErrorLine != nil, hasOutput: !output.isEmpty)
        let summary = buildSummary(
            status: status,
            kind: kind,
            errorCount: firstErrorLine == nil ? 0 : 1,
            failedTestCount: 0,
            firstMessage: firstErrorLine
        )
        return ParsedBuildOutput(
            status: status,
            errorCount: firstErrorLine == nil ? 0 : 1,
            failedTestCount: 0,
            failedTestNames: [],
            primaryLocation: nil,
            summary: summary
        )
    }

    private static func resolveStatus(exitCode: Int32?, hasFailures: Bool, hasOutput: Bool) -> BuildRunStatus {
        if let exitCode {
            return exitCode == 0 && !hasFailures ? .passed : .failed
        }
        if hasFailures { return .failed }
        return hasOutput ? .unknown : .unknown
    }

    private static func buildSummary(
        status: BuildRunStatus,
        kind: BuildRunKind,
        errorCount: Int,
        failedTestCount: Int,
        firstMessage: String?
    ) -> String {
        switch status {
        case .running:
            return kind == .test ? "Running tests…" : "Building…"
        case .passed:
            return kind == .test ? "All tests passed" : "Build succeeded"
        case .cancelled:
            return kind == .test ? "Test run cancelled" : "Build cancelled"
        case .unknown:
            return kind == .test ? "Test status unknown" : "Build status unknown"
        case .failed:
            if let firstMessage, !firstMessage.isEmpty {
                return firstMessage
            }
            if failedTestCount > 0 {
                return "\(failedTestCount) test\(failedTestCount == 1 ? "" : "s") failed"
            }
            if errorCount > 0 {
                return "\(errorCount) error\(errorCount == 1 ? "" : "s")"
            }
            return kind == .test ? "Tests failed" : "Build failed"
        }
    }

    private static func firstMatch(_ regex: NSRegularExpression?, in line: String) -> NSTextCheckingResult? {
        guard let regex else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range)
    }

    private static func group(_ match: NSTextCheckingResult, at index: Int, in line: String) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let nsRange = match.range(at: index)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: line) else { return nil }
        return String(line[range])
    }
}

/// Correlates multi-phase build/test events (`started` -> `diagnostic` -> `finished`/`cancelled`)
/// into a single deduplicated `BuildTestResult` per run.
public struct BuildEventCorrelator: Equatable, Sendable {
    private struct ActiveRun: Equatable, Sendable {
        var startedAt: Date
        var result: BuildTestResult
        var lastEmittedTerminalFingerprint: String?
    }

    private var runs: [String: ActiveRun] = [:]
    private let maxTrackedRuns = 24

    public init() {}

    public mutating func ingest(_ input: BuildEventInput) -> BuildTestResult? {
        let project = input.project.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeProject = project.isEmpty ? "Workspace" : project
        let key = (input.runID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? safeProject
        let toolchain = input.toolchain ?? .generic

        var active = runs[key] ?? ActiveRun(
            startedAt: input.timestamp,
            result: BuildTestResult(
                id: key,
                project: safeProject,
                toolchain: toolchain,
                kind: input.kind,
                status: .running,
                summary: input.kind == .test ? "Running tests…" : "Building…",
                updatedAt: input.timestamp
            )
        )

        active.result.project = safeProject
        if input.toolchain != nil {
            active.result.toolchain = toolchain
        }
        active.result.kind = input.kind
        active.result.updatedAt = input.timestamp

        let rawOutput = input.output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawOutput.isEmpty {
            active.result.rawLogSnippet = String(rawOutput.prefix(2_000))
        }

        switch input.phase {
        case .started:
            active.startedAt = input.timestamp
            active.lastEmittedTerminalFingerprint = nil
            active.result.status = .running
            active.result.exitCode = nil
            active.result.durationSeconds = nil
            active.result.errorCount = 0
            active.result.failedTestCount = 0
            active.result.failedTestNames = []
            active.result.primaryLocation = nil
            active.result.summary = input.kind == .test ? "Running tests…" : "Building…"
            runs[key] = active
            trimOldRunsIfNeeded()
            return active.result

        case .diagnostic:
            if !rawOutput.isEmpty {
                let parsed = BuildOutputParser.parse(
                    output: rawOutput,
                    toolchain: active.result.toolchain,
                    kind: active.result.kind,
                    exitCode: nil
                )
                active.result.errorCount += parsed.errorCount
                active.result.failedTestCount = max(active.result.failedTestCount, parsed.failedTestCount)
                for name in parsed.failedTestNames where !active.result.failedTestNames.contains(name) {
                    active.result.failedTestNames.append(name)
                }
                if active.result.primaryLocation == nil {
                    active.result.primaryLocation = parsed.primaryLocation
                }
                if parsed.status == .failed && !parsed.summary.isEmpty {
                    active.result.summary = parsed.summary
                }
            }
            runs[key] = active
            trimOldRunsIfNeeded()
            return active.result

        case .cancelled:
            active.result.status = .cancelled
            active.result.durationSeconds = input.durationSeconds ?? max(0, input.timestamp.timeIntervalSince(active.startedAt))
            active.result.summary = input.kind == .test ? "Test run cancelled" : "Build cancelled"
            let fingerprint = terminalFingerprint(for: active.result)
            if active.lastEmittedTerminalFingerprint == fingerprint {
                return nil
            }
            active.lastEmittedTerminalFingerprint = fingerprint
            runs[key] = active
            trimOldRunsIfNeeded()
            return active.result

        case .finished:
            let parsed = BuildOutputParser.parse(
                output: rawOutput,
                toolchain: active.result.toolchain,
                kind: active.result.kind,
                exitCode: input.exitCode
            )
            active.result.exitCode = input.exitCode
            active.result.durationSeconds = input.durationSeconds ?? max(0, input.timestamp.timeIntervalSince(active.startedAt))
            active.result.errorCount = max(active.result.errorCount, parsed.errorCount)
            active.result.failedTestCount = max(active.result.failedTestCount, parsed.failedTestCount)
            for name in parsed.failedTestNames where !active.result.failedTestNames.contains(name) {
                active.result.failedTestNames.append(name)
            }
            if active.result.primaryLocation == nil {
                active.result.primaryLocation = parsed.primaryLocation
            }
            if active.result.status == .running || parsed.status != .unknown {
                active.result.status = parsed.status
            }
            if parsed.status == .failed && active.result.summary.hasPrefix("Running") || active.result.summary.hasPrefix("Building") || parsed.status == .passed {
                active.result.summary = parsed.summary
            } else if active.result.summary.isEmpty {
                active.result.summary = parsed.summary
            }

            let fingerprint = terminalFingerprint(for: active.result)
            if active.lastEmittedTerminalFingerprint == fingerprint {
                return nil
            }
            active.lastEmittedTerminalFingerprint = fingerprint
            runs[key] = active
            trimOldRunsIfNeeded()
            return active.result
        }
    }

    private func terminalFingerprint(for result: BuildTestResult) -> String {
        "\(result.id)|\(result.status.rawValue)|\(result.exitCode.map(String.init) ?? "nil")|\(result.errorCount)|\(result.failedTestCount)|\(result.summary)"
    }

    private mutating func trimOldRunsIfNeeded() {
        guard runs.count > maxTrackedRuns else { return }
        let sorted = runs.sorted { $0.value.result.updatedAt < $1.value.result.updatedAt }
        for (key, _) in sorted.prefix(runs.count - maxTrackedRuns) {
            runs.removeValue(forKey: key)
        }
    }
}
