import Foundation

public enum AgentConflictKind: String, Equatable, Sendable, Codable, CaseIterable {
    case sameFileModified
    case sameFileRecentlyModified
    case sameBranchConcurrentWork
    case sharedWorktree
    case staleSession
}

public enum AgentConflictConfidence: String, Equatable, Sendable, Codable, Comparable {
    case warning
    case confirmed

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs == .warning && rhs == .confirmed
    }
}

public struct AgentConflict: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: AgentConflictKind
    public var confidence: AgentConflictConfidence
    public var sessions: [AgentSession.Key]
    public var filePath: String?
    public var repo: String?
    public var branch: String?
    public var title: String
    public var detail: String

    public init(
        id: String,
        kind: AgentConflictKind,
        confidence: AgentConflictConfidence,
        sessions: [AgentSession.Key],
        filePath: String? = nil,
        repo: String? = nil,
        branch: String? = nil,
        title: String,
        detail: String
    ) {
        self.id = id
        self.kind = kind
        self.confidence = confidence
        self.sessions = sessions
        self.filePath = filePath
        self.repo = repo
        self.branch = branch
        self.title = title
        self.detail = detail
    }
}

/// Pure, evidence-based conflict detector across active and recently finished agent sessions.
/// Separates confirmed concurrent file edits from contextual warnings without guessing unlinked file changes.
public enum AgentConflictDetector {
    public static func detect(
        sessions: [AgentSession],
        now: Date = Date(),
        recentWindow: TimeInterval = 300,
        staleThreshold: TimeInterval = 900
    ) -> [AgentConflict] {
        var conflicts: [AgentConflict] = []
        let activeSessions = sessions.filter(\.isActive)

        // 1. Same File Modified (confirmed: 2+ active sessions explicitly editing the same file)
        var activeFileOwners: [String: [AgentSession]] = [:]
        for session in activeSessions {
            for path in Set(session.modifiedFiles.map(normalizePath)).filter({ !$0.isEmpty }) {
                activeFileOwners[path, default: []].append(session)
            }
        }
        for (path, owners) in activeFileOwners where owners.count >= 2 {
            let sortedOwners = owners.sorted { "\($0.source):\($0.session)" < "\($1.source):\($1.session)" }
            let keys = sortedOwners.map(\.id)
            let filename = (path as NSString).lastPathComponent
            let agentList = sortedOwners.map { $0.source }.joined(separator: " + ")
            conflicts.append(AgentConflict(
                id: "sameFile:\(path)",
                kind: .sameFileModified,
                confidence: .confirmed,
                sessions: keys,
                filePath: path,
                repo: sortedOwners.compactMap(\.repo).first,
                branch: sortedOwners.compactMap(\.branch).first,
                title: "\(sortedOwners.count) agents editing \(filename)",
                detail: agentList
            ))
        }

        // 2. Same File Recently Modified (warning: active session edits a file recently modified by a finished session)
        let recentFinished = sessions.filter {
            !$0.isActive && now.timeIntervalSince($0.updatedAt) <= recentWindow
        }
        var recentFileOwners: [String: [AgentSession]] = [:]
        for session in recentFinished {
            for path in Set(session.modifiedFiles.map(normalizePath)).filter({ !$0.isEmpty }) {
                recentFileOwners[path, default: []].append(session)
            }
        }
        for (path, activeOwners) in activeFileOwners {
            guard let finishedOwners = recentFileOwners[path] else { continue }
            let combined = (activeOwners + finishedOwners).sorted { "\($0.source):\($0.session)" < "\($1.source):\($1.session)" }
            let filename = (path as NSString).lastPathComponent
            conflicts.append(AgentConflict(
                id: "recentFile:\(path)",
                kind: .sameFileRecentlyModified,
                confidence: .warning,
                sessions: combined.map(\.id),
                filePath: path,
                repo: combined.compactMap(\.repo).first,
                branch: combined.compactMap(\.branch).first,
                title: "Recent overlap on \(filename)",
                detail: combined.map(\.source).joined(separator: " & ")
            ))
        }

        // 3. Same Branch Concurrent Work (warning: 2+ active sessions on same repo + branch)
        var branchGroups: [String: [AgentSession]] = [:]
        for session in activeSessions {
            guard let branch = session.branch?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !branch.isEmpty else { continue }
            let repo = (session.repo ?? session.cwdBasename ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !repo.isEmpty else { continue }
            branchGroups["\(repo)::\(branch)", default: []].append(session)
        }
        for (groupKey, group) in branchGroups where group.count >= 2 {
            let sorted = group.sorted { "\($0.source):\($0.session)" < "\($1.source):\($1.session)" }
            let parts = groupKey.components(separatedBy: "::")
            let repo = parts.first ?? ""
            let branch = parts.last ?? ""
            conflicts.append(AgentConflict(
                id: "sameBranch:\(groupKey)",
                kind: .sameBranchConcurrentWork,
                confidence: .warning,
                sessions: sorted.map(\.id),
                repo: repo,
                branch: branch,
                title: "\(sorted.count) agents on \(branch)",
                detail: "\(repo) · \(sorted.map(\.source).joined(separator: ", "))"
            ))
        }

        // 4. Shared Worktree (warning: 2+ active sessions sharing the same worktree/cwd)
        var worktreeGroups: [String: [AgentSession]] = [:]
        for session in activeSessions {
            let rawWT = (session.worktree ?? session.cwd)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawWT.isEmpty else { continue }
            worktreeGroups[normalizePath(rawWT), default: []].append(session)
        }
        for (wt, group) in worktreeGroups where group.count >= 2 {
            let sorted = group.sorted { "\($0.source):\($0.session)" < "\($1.source):\($1.session)" }
            let wtName = (wt as NSString).lastPathComponent
            conflicts.append(AgentConflict(
                id: "sharedWorktree:\(wt)",
                kind: .sharedWorktree,
                confidence: .warning,
                sessions: sorted.map(\.id),
                repo: sorted.compactMap(\.repo).first,
                title: "\(sorted.count) agents in \(wtName)",
                detail: sorted.map(\.source).joined(separator: " + ")
            ))
        }

        // 5. Stale Session (warning: active session with no heartbeat beyond staleThreshold)
        for session in activeSessions where now.timeIntervalSince(session.updatedAt) >= staleThreshold {
            let mins = Int(now.timeIntervalSince(session.updatedAt) / 60)
            conflicts.append(AgentConflict(
                id: "stale:\(session.source):\(session.session)",
                kind: .staleSession,
                confidence: .warning,
                sessions: [session.id],
                repo: session.repo ?? session.cwdBasename,
                branch: session.branch,
                title: "Stale \(session.source) session",
                detail: "Idle \(mins)m"
            ))
        }

        return conflicts.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.id < rhs.id
        }
    }

    private static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }
}

