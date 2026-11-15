import Foundation

public enum NotchMode: Equatable, Sendable {
    case collapsed
    case expanded
    case fileDrop
    case clipboard
    case commandPalette
    case errorLens(title: String, log: String)
    case toast(Toast)
}

public struct ErrorLensPayload: Equatable, Sendable {
    public var title: String
    public var log: String
}

public struct NotchState: Equatable, Sendable {
    public var isHovering = false
    public var isDragging = false
    public var isClipboardOpen = false
    public var isCommandPaletteOpen = false
    public var activeError: ErrorLensPayload?
    public var activeToast: Toast?
    /// Sorted by priority (desc), FIFO within a priority.
    public var pendingToasts: [Toast] = []
    public var agentSessions: [AgentSession] = []
    public var devServers: [DevServer] = []
    public var stagedFiles: [URL] = []
    public var clipboard = ClipboardHistory()
    public var gitStatus: GitStatus?
    public var activeRepoPath: String?
    public var repoTasks: [RepoTask] = []

    public init() {}

    public var workingAgentCount: Int {
        agentSessions.count(where: { $0.state == .working })
    }

    public var waitingAgentCount: Int {
        agentSessions.count(where: { $0.state == .waiting })
    }

    public var hasActiveAgents: Bool {
        agentSessions.contains(where: \.isActive)
    }

    /// Derived, never stored, so impossible states can't exist.
    public var mode: NotchMode {
        if isDragging { return .fileDrop }
        if isClipboardOpen { return .clipboard }
        if isCommandPaletteOpen { return .commandPalette }
        if let activeError { return .errorLens(title: activeError.title, log: activeError.log) }
        if let activeToast { return .toast(activeToast) }
        if isHovering { return .expanded }
        return .collapsed
    }
}

public enum NotchEvent: Sendable, Equatable {
    case hoverChanged(Bool)
    case dragChanged(Bool)
    case postToast(Toast)
    case toastExpired(UUID)
    case dismissToast
    case recordActivity(ActivityEvent, at: Date)
    case clearFinishedAgents
    case devServersUpdated([DevServer])
    case stageFiles([URL])
    case removeStagedFile(URL)
    case clearStagedFiles
    case clipboardRecorded(ClipboardItem.Content, at: Date)
    case toggleClipboard
    case setClipboardOpen(Bool)
    case toggleCommandPalette
    case setCommandPaletteOpen(Bool)
    case setActiveRepoPath(String)
    case repoTasksUpdated([RepoTask])
    case openErrorLens(title: String, log: String)
    case closeErrorLens
    case gitStatusUpdated(GitStatus?)
}

public enum NotchEffect: Sendable, Equatable {
    case scheduleExpiry(UUID, after: Duration)
    case cancelExpiry(UUID)
}

public enum NotchReducer {
    public static let maxPending = 8

    public static func reduce(_ s: inout NotchState, _ event: NotchEvent) -> [NotchEffect] {
        switch event {
        case .hoverChanged(let h):
            s.isHovering = h
            return []
        case .dragChanged(let d):
            s.isDragging = d
            return []
        case .postToast(let t):
            return post(t, into: &s)
        case .toastExpired(let id):
            guard s.activeToast?.id == id else { return [] } // stale timer
            return advance(&s)
        case .dismissToast:
            guard let current = s.activeToast else { return [] }
            return [.cancelExpiry(current.id)] + advance(&s)
        case .recordActivity(let ev, let now):
            return recordActivity(ev, at: now, into: &s)
        case .clearFinishedAgents:
            s.agentSessions.removeAll { !$0.isActive }
            return []
        case .devServersUpdated(let servers):
            s.devServers = servers
            return []
        case .stageFiles(let urls):
            for url in urls {
                let normalized = url.standardizedFileURL
                if !s.stagedFiles.contains(where: { $0.standardizedFileURL == normalized }) {
                    s.stagedFiles.append(normalized)
                }
            }
            if s.stagedFiles.count > 20 {
                s.stagedFiles.removeFirst(s.stagedFiles.count - 20)
            }
            return []
        case .removeStagedFile(let url):
            let normalized = url.standardizedFileURL
            s.stagedFiles.removeAll { $0.standardizedFileURL == normalized }
            return []
        case .clearStagedFiles:
            s.stagedFiles.removeAll()
            return []
        case .clipboardRecorded(let content, let date):
            s.clipboard.record(content, at: date)
            return []
        case .toggleClipboard:
            s.isClipboardOpen.toggle()
            return []
        case .setClipboardOpen(let open):
            s.isClipboardOpen = open
            return []
        case .toggleCommandPalette:
            s.isCommandPaletteOpen.toggle()
            return []
        case .setCommandPaletteOpen(let open):
            s.isCommandPaletteOpen = open
            return []
        case .setActiveRepoPath(let path):
            s.activeRepoPath = path
            return []
        case .repoTasksUpdated(let tasks):
            s.repoTasks = tasks
            return []
        case .openErrorLens(let title, let log):
            s.activeError = ErrorLensPayload(title: title, log: log)
            return []
        case .closeErrorLens:
            s.activeError = nil
            return []
        case .gitStatusUpdated(let status):
            s.gitStatus = status
            return []
        }
    }

    private static let maxAgentSessions = 12

    private static func recordActivity(_ ev: ActivityEvent, at now: Date, into s: inout NotchState) -> [NotchEffect] {
        let key = AgentSession.Key(source: ev.source, session: ev.session)
        if let idx = s.agentSessions.firstIndex(where: { $0.id == key }) {
            let wasActive = s.agentSessions[idx].isActive
            s.agentSessions[idx].state = ev.state
            s.agentSessions[idx].title = ev.title ?? s.agentSessions[idx].title
            s.agentSessions[idx].cwd = ev.cwd ?? s.agentSessions[idx].cwd
            if ev.state == .working && !wasActive {
                s.agentSessions[idx].startedAt = now
            }
            s.agentSessions[idx].updatedAt = now
        } else {
            s.agentSessions.append(AgentSession(
                source: ev.source,
                session: ev.session,
                state: ev.state,
                title: ev.title,
                cwd: ev.cwd,
                startedAt: now,
                updatedAt: now
            ))
        }

        s.agentSessions.sort { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            return lhs.updatedAt > rhs.updatedAt
        }
        if s.agentSessions.count > maxAgentSessions {
            s.agentSessions.removeLast(s.agentSessions.count - maxAgentSessions)
        }

        guard ev.state != .working else { return [] }

        let (symbol, tint, priority, ttl): (String, Toast.Tint, Toast.Priority, Double) = switch ev.state {
        case .waiting: ("hand.raised.fill", .waiting, .critical, 6)
        case .done: ("checkmark", .success, .normal, 3)
        case .failed: ("xmark", .failure, .high, 5)
        case .working: ("gearshape.2.fill", .info, .low, 2)
        }
        let cwdName = ev.cwd.flatMap { let n = ($0 as NSString).lastPathComponent; return n.isEmpty ? nil : n }
        let subtitle = [ev.source, cwdName].compactMap { $0 }.joined(separator: " · ")
        let toast = Toast(
            key: "activity:\(ev.source):\(ev.session)",
            title: ev.title ?? "\(ev.source) \(ev.state.rawValue)",
            subtitle: subtitle.isEmpty ? nil : subtitle,
            symbol: symbol,
            tint: tint,
            priority: priority,
            duration: .seconds(ttl)
        )
        return post(toast, into: &s)
    }

    private static func post(_ t: Toast, into s: inout NotchState) -> [NotchEffect] {
        if let key = t.key {
            if let current = s.activeToast, current.key == key {
                s.activeToast = t
                return [.cancelExpiry(current.id), .scheduleExpiry(t.id, after: t.duration)]
            }
            if let i = s.pendingToasts.firstIndex(where: { $0.key == key }) {
                s.pendingToasts.remove(at: i)
                enqueue(t, into: &s)
                return []
            }
        }
        guard let current = s.activeToast else {
            s.activeToast = t
            return [.scheduleExpiry(t.id, after: t.duration)]
        }
        if t.priority > current.priority {
            // Preempted toast goes to the front of its priority band and gets a fresh timer later.
            let i = s.pendingToasts.firstIndex(where: { $0.priority <= current.priority }) ?? s.pendingToasts.endIndex
            s.pendingToasts.insert(current, at: i)
            s.activeToast = t
            trim(&s)
            return [.cancelExpiry(current.id), .scheduleExpiry(t.id, after: t.duration)]
        }
        enqueue(t, into: &s)
        return []
    }

    private static func enqueue(_ t: Toast, into s: inout NotchState) {
        let i = s.pendingToasts.firstIndex(where: { $0.priority < t.priority }) ?? s.pendingToasts.endIndex
        s.pendingToasts.insert(t, at: i)
        trim(&s)
    }

    private static func trim(_ s: inout NotchState) {
        if s.pendingToasts.count > maxPending { s.pendingToasts.removeLast(s.pendingToasts.count - maxPending) }
    }

    private static func advance(_ s: inout NotchState) -> [NotchEffect] {
        guard !s.pendingToasts.isEmpty else {
            s.activeToast = nil
            return []
        }
        let next = s.pendingToasts.removeFirst()
        s.activeToast = next
        return [.scheduleExpiry(next.id, after: next.duration)]
    }
}

