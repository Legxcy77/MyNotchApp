import Foundation

public enum CIRunStatus: String, Equatable, Sendable, Codable {
    case queued
    case inProgress
    case success
    case failure
    case cancelled
    case unknown
    case connectionError
}

public struct CIRunRecord: Equatable, Sendable, Identifiable {
    public var id: String
    public var repository: String
    public var branch: String
    public var commitSHA: String
    public var workflow: String
    public var status: CIRunStatus
    public var startedAt: Date?
    public var completedAt: Date?
    public var failureSummary: String?
    public var runURL: URL?
    public var syncedAt: Date
    public var isLive: Bool

    public init(
        id: String,
        repository: String,
        branch: String,
        commitSHA: String,
        workflow: String,
        status: CIRunStatus,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        failureSummary: String? = nil,
        runURL: URL? = nil,
        syncedAt: Date = Date(),
        isLive: Bool = true
    ) {
        self.id = id
        self.repository = repository
        self.branch = branch
        self.commitSHA = commitSHA
        self.workflow = workflow
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.failureSummary = failureSummary
        self.runURL = runURL
        self.syncedAt = syncedAt
        self.isLive = isLive
    }
}

public enum CIWatchtowerParser {
    public static func parseGitHubWorkflowRuns(
        _ data: Data,
        repository: String,
        syncedAt: Date = Date(),
        isLive: Bool = true
    ) -> [CIRunRecord] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runs = json["workflow_runs"] as? [[String: Any]] else {
            return []
        }

        let iso = ISO8601DateFormatter()
        return runs.compactMap { item -> CIRunRecord? in
            guard let idNum = item["id"] as? Int64 ?? (item["id"] as? Int).map(Int64.init) else {
                return nil
            }
            let branch = (item["head_branch"] as? String) ?? "unknown"
            let sha = String(((item["head_sha"] as? String) ?? "").prefix(7))
            let workflow = (item["name"] as? String) ?? "Workflow"
            let rawStatus = (item["status"] as? String) ?? ""
            let rawConclusion = (item["conclusion"] as? String) ?? ""
            let status = mapStatus(status: rawStatus, conclusion: rawConclusion)
            let startedAt = (item["run_started_at"] as? String).flatMap { iso.date(from: $0) }
            let completedAt = (item["updated_at"] as? String).flatMap { iso.date(from: $0) }
            let url = (item["html_url"] as? String).flatMap(URL.init(string:))

            return CIRunRecord(
                id: "\(idNum)",
                repository: repository,
                branch: branch,
                commitSHA: sha,
                workflow: workflow,
                status: status,
                startedAt: startedAt,
                completedAt: status == .inProgress || status == .queued ? nil : completedAt,
                failureSummary: status == .failure ? "\(workflow) failed on \(branch)" : nil,
                runURL: url,
                syncedAt: syncedAt,
                isLive: isLive
            )
        }
    }

    public static func mapStatus(status: String, conclusion: String) -> CIRunStatus {
        switch status.lowercased() {
        case "queued", "waiting":
            return .queued
        case "in_progress":
            return .inProgress
        case "completed":
            switch conclusion.lowercased() {
            case "success": return .success
            case "failure", "timed_out": return .failure
            case "cancelled", "skipped": return .cancelled
            default: return .unknown
            }
        default:
            return .unknown
        }
    }
}

