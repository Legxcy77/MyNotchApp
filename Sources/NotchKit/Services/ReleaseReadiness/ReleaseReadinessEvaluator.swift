import Foundation

public enum ReleaseReadinessStatus: String, Equatable, Sendable, Codable {
    case ready
    case needsAttention
    case blocked
    case unknown
}

public struct ReleaseCheckItem: Equatable, Sendable, Identifiable {
    public enum State: String, Equatable, Sendable, Codable {
        case passed
        case warning
        case blocked
        case unknown
    }

    public var id: String
    public var title: String
    public var state: State
    public var detail: String

    public init(id: String, title: String, state: State, detail: String) {
        self.id = id
        self.title = title
        self.state = state
        self.detail = detail
    }
}

public struct ReleaseReadinessReport: Equatable, Sendable {
    public var status: ReleaseReadinessStatus
    public var checks: [ReleaseCheckItem]
    public var evaluatedAt: Date

    public init(status: ReleaseReadinessStatus, checks: [ReleaseCheckItem], evaluatedAt: Date = Date()) {
        self.status = status
        self.checks = checks
        self.evaluatedAt = evaluatedAt
    }
}

/// Evaluates whether the workspace is ready for release.
/// Never treats `.unknown` checks as `.passed`.
public enum ReleaseReadinessEvaluator {
    public static func evaluate(
        latestBuild: BuildTestResult?,
        gitStatus: GitStatus?,
        agentConflicts: [AgentConflict],
        ciRun: CIRunRecord? = nil,
        envReport: EnvGuardReport? = nil,
        securityFindings: [DependencyFinding] = [],
        now: Date = Date()
    ) -> ReleaseReadinessReport {
        var checks: [ReleaseCheckItem] = []

        // 1. Build / Test
        if let build = latestBuild {
            let state: ReleaseCheckItem.State = switch build.status {
            case .passed: .passed
            case .failed: .blocked
            case .running, .cancelled: .warning
            case .unknown: .unknown
            }
            checks.append(ReleaseCheckItem(
                id: "build",
                title: "Build & Tests",
                state: state,
                detail: "\(build.project): \(build.summary)"
            ))
        } else {
            checks.append(ReleaseCheckItem(id: "build", title: "Build & Tests", state: .unknown, detail: "No recent build/test run"))
        }

        // 2. Git Working Tree
        if let git = gitStatus {
            let state: ReleaseCheckItem.State = git.dirtyCount == 0 ? .passed : .warning
            checks.append(ReleaseCheckItem(
                id: "git",
                title: "Git Working Tree",
                state: state,
                detail: git.dirtyCount == 0 ? "Clean (\(git.branch))" : "\(git.dirtyCount) uncommitted changes on \(git.branch)"
            ))
        } else {
            checks.append(ReleaseCheckItem(id: "git", title: "Git Working Tree", state: .unknown, detail: "No active repository"))
        }

        // 3. Agent Conflicts
        if agentConflicts.contains(where: { $0.confidence == .confirmed }) {
            checks.append(ReleaseCheckItem(id: "conflicts", title: "Agent Conflicts", state: .blocked, detail: "Confirmed concurrent file edit"))
        } else if !agentConflicts.isEmpty {
            checks.append(ReleaseCheckItem(id: "conflicts", title: "Agent Conflicts", state: .warning, detail: "\(agentConflicts.count) warning(s)"))
        } else {
            checks.append(ReleaseCheckItem(id: "conflicts", title: "Agent Conflicts", state: .passed, detail: "No active conflicts"))
        }

        // 4. CI Pipeline
        if let ci = ciRun {
            let ciState: ReleaseCheckItem.State = switch ci.status {
            case .success: .passed
            case .failure, .connectionError: .blocked
            case .queued, .inProgress, .cancelled: .warning
            case .unknown: .unknown
            }
            checks.append(ReleaseCheckItem(id: "ci", title: "CI Pipeline", state: ciState, detail: "\(ci.workflow) (\(ci.status.rawValue))"))
        } else {
            checks.append(ReleaseCheckItem(id: "ci", title: "CI Pipeline", state: .unknown, detail: "Not synced"))
        }

        // 5. Env Guard
        if let env = envReport {
            let envState: ReleaseCheckItem.State = env.isHealthy ? .passed : .blocked
            let detail = env.isHealthy ? "All required keys present" : "Missing: \(env.missingKeys.joined(separator: ", "))"
            checks.append(ReleaseCheckItem(id: "env", title: "Environment Config", state: envState, detail: detail))
        } else {
            checks.append(ReleaseCheckItem(id: "env", title: "Environment Config", state: .unknown, detail: "No .env.example check"))
        }

        // 6. Security Advisories
        let criticalOrHigh = securityFindings.filter { $0.severity >= .high && $0.isConfirmed }
        if !criticalOrHigh.isEmpty {
            checks.append(ReleaseCheckItem(id: "security", title: "Dependencies", state: .blocked, detail: "\(criticalOrHigh.count) high/critical advisory"))
        } else if !securityFindings.isEmpty {
            checks.append(ReleaseCheckItem(id: "security", title: "Dependencies", state: .warning, detail: "\(securityFindings.count) low/moderate advisory"))
        } else {
            checks.append(ReleaseCheckItem(id: "security", title: "Dependencies", state: .passed, detail: "No known advisories"))
        }

        let overall: ReleaseReadinessStatus
        if checks.contains(where: { $0.state == .blocked }) {
            overall = .blocked
        } else if checks.allSatisfy({ $0.state == .unknown }) {
            overall = .unknown
        } else if checks.contains(where: { $0.state == .warning || $0.state == .unknown }) {
            overall = .needsAttention
        } else {
            overall = .ready
        }

        return ReleaseReadinessReport(status: overall, checks: checks, evaluatedAt: now)
    }
}

