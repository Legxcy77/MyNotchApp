import Foundation

public enum NotchMode: Equatable, Sendable {
    case collapsed
    case expanded
    case fileDrop
    case clipboard
    case commandPalette
    case quickAI
    case errorLens(title: String, log: String)
    case toast(Toast)
}

public struct ErrorLensPayload: Equatable, Sendable {
    public var title: String
    public var log: String
}

public struct FaceScanEarStatus: Equatable, Sendable {
    public var isVerified: Bool
    public var isAwaitingBlink: Bool
    public var instruction: String

    public init(isVerified: Bool = false, isAwaitingBlink: Bool = false, instruction: String) {
        self.isVerified = isVerified
        self.isAwaitingBlink = isAwaitingBlink
        self.instruction = instruction
    }
}

public enum ExpandedTab: String, Equatable, Sendable, CaseIterable {
    case overview
    case media
    case tools
    case drop
    case timeline
}

public struct AIChatMessage: Identifiable, Equatable, Sendable {
    public enum Role: String, Sendable, Equatable {
        case user
        case model
    }

    public let id: UUID
    public let role: Role
    public var text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

public struct NotchState: Equatable, Sendable {
    public var isHovering = false
    public var isDragging = false
    public var isClipboardOpen = false
    public var isCommandPaletteOpen = false
    public var isQuickAIOpen = false
    public var aiPrompt = ""
    public var aiResponse = ""
    public var aiMessages: [AIChatMessage] = []
    public var isAILoading = false
    public var activeError: ErrorLensPayload?
    public var activeToast: Toast?
    /// Sorted by priority (desc), FIFO within a priority.
    public var pendingToasts: [Toast] = []
    public var agentSessions: [AgentSession] = []
    public var devServers: [DevServer] = []
    public var dockerContainers: [DockerContainer] = []
    public var stagedFiles: [URL] = []
    public var clipboard = ClipboardHistory()
    public var gitStatus: GitStatus?
    public var activeRepoPath: String?
    public var repoTasks: [RepoTask] = []
    public var expandedTab: ExpandedTab = .overview
    public var runHistory: [RunRecord] = []
    public var nowPlaying: NowPlayingTrack?
    public var lyrics: LRCDocument?
    public var nextMeeting: UpcomingMeeting?
    public var focusSession: FocusSession?
    public var focusDurationMinutes: Int = 25
    public var systemPulse: [SystemPulseSample] = []
    public var faceScanEar: FaceScanEarStatus? = nil
    public var audioState = AudioStateSnapshot()
    public var isClipboardPaused = false
    public var notesPayload = NotesAndTasksPayload()
    public var androidDrop = AndroidDropStatus()
    public var latestBuildResult: BuildTestResult?
    public var buildHistory: [BuildTestResult] = []
    public var buildCorrelator = BuildEventCorrelator()
    public var agentConflicts: [AgentConflict] = []
    public var acknowledgedConflictIDs: Set<String> = []
    public var worklogEntries: [WorklogEntry] = []
    public var worklogRange: WorklogRange = .today
    public var changeImpact: ChangeImpactReport?
    public var ciRuns: [CIRunRecord] = []
    public var databaseReport: DatabaseHealthReport?
    public var dependencyFindings: [DependencyFinding] = []
    public var envGuardReport: EnvGuardReport?
    public var releaseReadiness: ReleaseReadinessReport?

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

    public var hasActiveMedia: Bool {
        nowPlaying?.isPlaying == true
    }

    public var hasUrgentMeeting: Bool {
        guard let nextMeeting else { return false }
        return MeetingDetector.isWithinCountdownWindow(nextMeeting)
    }

    public var hasCockpitSignal: Bool {
        latestBuildResult?.status == .failed
            || latestBuildResult?.status == .running
            || !agentConflicts.isEmpty
            || !devServers.isEmpty
            || (gitStatus?.dirtyCount ?? 0) > 0
    }

    public var showsEars: Bool {
        hasActiveAgents || hasActiveMedia || hasUrgentMeeting || focusSession != nil || faceScanEar != nil || hasCockpitSignal
    }

    /// Derived, never stored, so impossible states can't exist.
    public var mode: NotchMode {
        if isDragging { return .fileDrop }
        if isClipboardOpen { return .clipboard }
        if isCommandPaletteOpen { return .commandPalette }
        if isQuickAIOpen { return .quickAI }
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
    case dockerContainersUpdated([DockerContainer])
    case faceScanEarUpdated(FaceScanEarStatus?)
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
    case recordRun(RunRecord)
    case clearRunHistory
    case setExpandedTab(ExpandedTab)
    case toggleQuickAI
    case setQuickAIOpen(Bool)
    case setAIPrompt(String)
    case aiResponseUpdated(String, isLoading: Bool)
    case appendAIChatMessage(AIChatMessage)
    case updateLastAIChatMessage(String, isLoading: Bool)
    case clearAIChat
    case nowPlayingUpdated(NowPlayingTrack?)
    case lyricsUpdated(LRCDocument?)
    case adjustLyricsOffset(TimeInterval)
    case nextMeetingUpdated(UpcomingMeeting?)
    case startFocus(minutes: Int, at: Date)
    case stopFocus
    case setFocusDuration(Int)
    case systemPulseUpdated([SystemPulseSample])
    case audioStateUpdated(AudioStateSnapshot)
    case toggleClipboardPaused
    case setQuickNote(String)
    case addQuickTask(String)
    case toggleQuickTask(UUID)
    case removeQuickTask(UUID)
    case androidDropUpdated(AndroidDropStatus)
    case buildEvent(BuildEventInput, at: Date = .now)
    case worklogUpdated([WorklogEntry])
    case setWorklogRange(WorklogRange)
    case worklogAIExplanationUpdated(id: UUID, explanation: String)
    case changeImpactUpdated(ChangeImpactReport?)
    case ciRunsUpdated([CIRunRecord])
    case databaseReportUpdated(DatabaseHealthReport?)
    case dependencyFindingsUpdated([DependencyFinding])
    case envGuardUpdated(EnvGuardReport?)
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
        case .buildEvent(let input, let now):
            return recordBuildEvent(input, at: now, into: &s)
        case .clearFinishedAgents:
            s.agentSessions.removeAll { !$0.isActive }
            s.agentConflicts = AgentConflictDetector.detect(sessions: s.agentSessions, now: Date())
            s.acknowledgedConflictIDs = s.acknowledgedConflictIDs.intersection(Set(s.agentConflicts.map(\.id)))
            recomputeReleaseReadiness(into: &s)
            return []
        case .devServersUpdated(let servers):
            let stopped = s.devServers.first { prev in
                !prev.isProtected && !servers.contains(where: { $0.port == prev.port })
            }
            s.devServers = servers
            if let stopped {
                return post(Toast(
                    key: "server-stopped:\(stopped.port)",
                    title: "localhost:\(stopped.port)",
                    subtitle: "Closed · Stopped",
                    symbol: "stop.circle",
                    tint: .neutral,
                    priority: .normal,
                    duration: .seconds(2.5)
                ), into: &s)
            }
            return []
        case .dockerContainersUpdated(let containers):
            s.dockerContainers = containers
            return []
        case .faceScanEarUpdated(let status):
            s.faceScanEar = status
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
            guard !s.isClipboardPaused else { return [] }
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
        case .worklogUpdated(let entries):
            s.worklogEntries = entries
            return []
        case .setWorklogRange(let range):
            s.worklogRange = range
            return []
        case .worklogAIExplanationUpdated(let id, let explanation):
            if let idx = s.worklogEntries.firstIndex(where: { $0.id == id }) {
                s.worklogEntries[idx].aiExplanation = explanation
            }
            return []
        case .closeErrorLens:
            s.activeError = nil
            return []
        case .gitStatusUpdated(let status):
            s.gitStatus = status
            recomputeReleaseReadiness(into: &s)
            return []
        case .changeImpactUpdated(let report):
            s.changeImpact = report
            return []
        case .ciRunsUpdated(let runs):
            s.ciRuns = runs
            recomputeReleaseReadiness(into: &s)
            return []
        case .databaseReportUpdated(let report):
            s.databaseReport = report
            return []
        case .dependencyFindingsUpdated(let findings):
            s.dependencyFindings = findings
            recomputeReleaseReadiness(into: &s)
            return []
        case .envGuardUpdated(let report):
            s.envGuardReport = report
            recomputeReleaseReadiness(into: &s)
            return []
        case .recordRun(let record):
            appendRun(record, into: &s)
            return []
        case .clearRunHistory:
            s.runHistory.removeAll()
            return []
        case .setExpandedTab(let tab):
            s.expandedTab = tab
            return []
        case .toggleQuickAI:
            s.isQuickAIOpen.toggle()
            return []
        case .setQuickAIOpen(let open):
            s.isQuickAIOpen = open
            return []
        case .setAIPrompt(let prompt):
            s.aiPrompt = prompt
            return []
        case .aiResponseUpdated(let text, let loading):
            s.aiResponse = text
            s.isAILoading = loading
            return []
        case .appendAIChatMessage(let msg):
            s.aiMessages.append(msg)
            if s.aiMessages.count > 40 {
                s.aiMessages.removeFirst(s.aiMessages.count - 40)
            }
            return []
        case .updateLastAIChatMessage(let text, let loading):
            s.aiResponse = text
            s.isAILoading = loading
            if !s.aiMessages.isEmpty {
                s.aiMessages[s.aiMessages.count - 1].text = text
            }
            return []
        case .clearAIChat:
            s.aiMessages.removeAll()
            s.aiResponse = ""
            s.aiPrompt = ""
            s.isAILoading = false
            return []
        case .nowPlayingUpdated(let track):
            s.nowPlaying = track
            return []
        case .lyricsUpdated(let doc):
            s.lyrics = doc
            return []
        case .adjustLyricsOffset(let delta):
            s.lyrics = s.lyrics?.withOffset(delta)
            return []
        case .nextMeetingUpdated(let meeting):
            s.nextMeeting = meeting
            return []
        case .startFocus(let minutes, let now):
            s.focusDurationMinutes = max(1, minutes)
            s.focusSession = FocusSession(startedAt: now, duration: TimeInterval(max(1, minutes) * 60))
            return []
        case .stopFocus:
            s.focusSession = nil
            return []
        case .setFocusDuration(let minutes):
            s.focusDurationMinutes = max(1, minutes)
            return []
        case .systemPulseUpdated(let samples):
            s.systemPulse = samples
            return []
        case .audioStateUpdated(let audio):
            s.audioState = audio
            return []
        case .toggleClipboardPaused:
            s.isClipboardPaused.toggle()
            return []
        case .setQuickNote(let text):
            s.notesPayload.note = text
            return []
        case .addQuickTask(let title):
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            s.notesPayload.tasks.insert(QuickTaskItem(title: trimmed), at: 0)
            return []
        case .toggleQuickTask(let id):
            if let idx = s.notesPayload.tasks.firstIndex(where: { $0.id == id }) {
                s.notesPayload.tasks[idx].isDone.toggle()
            }
            return []
        case .removeQuickTask(let id):
            s.notesPayload.tasks.removeAll { $0.id == id }
            return []
        case .androidDropUpdated(let status):
            s.androidDrop = status
            return []
        }
    }

    private static let maxAgentSessions = 12
    private static let maxRunHistory = 30

    private static func appendRun(_ record: RunRecord, into s: inout NotchState) {
        s.runHistory.insert(record, at: 0)
        if s.runHistory.count > maxRunHistory {
            s.runHistory.removeLast(s.runHistory.count - maxRunHistory)
        }
    }

    private static func recordActivity(_ ev: ActivityEvent, at now: Date, into s: inout NotchState) -> [NotchEffect] {
        let key = AgentSession.Key(source: ev.source, session: ev.session)
        let startedAt: Date
        let resolvedTitle: String
        let resolvedCwd: String?
        if let idx = s.agentSessions.firstIndex(where: { $0.id == key }) {
            let wasActive = s.agentSessions[idx].isActive
            s.agentSessions[idx].state = ev.state
            s.agentSessions[idx].title = ev.title ?? s.agentSessions[idx].title
            s.agentSessions[idx].cwd = ev.cwd ?? s.agentSessions[idx].cwd
            s.agentSessions[idx].repo = ev.repo ?? s.agentSessions[idx].repo
            s.agentSessions[idx].worktree = ev.worktree ?? s.agentSessions[idx].worktree
            s.agentSessions[idx].branch = ev.branch ?? s.agentSessions[idx].branch
            for file in ev.modifiedFiles where !s.agentSessions[idx].modifiedFiles.contains(file) {
                s.agentSessions[idx].modifiedFiles.append(file)
            }
            if ev.state == .working && !wasActive {
                s.agentSessions[idx].startedAt = now
            }
            s.agentSessions[idx].updatedAt = now
            startedAt = s.agentSessions[idx].startedAt
            resolvedTitle = s.agentSessions[idx].title ?? ev.source
            resolvedCwd = s.agentSessions[idx].cwd
        } else {
            s.agentSessions.append(AgentSession(
                source: ev.source,
                session: ev.session,
                state: ev.state,
                title: ev.title,
                cwd: ev.cwd,
                repo: ev.repo,
                worktree: ev.worktree,
                branch: ev.branch,
                modifiedFiles: ev.modifiedFiles,
                startedAt: now,
                updatedAt: now
            ))
            startedAt = now
            resolvedTitle = ev.title ?? ev.source
            resolvedCwd = ev.cwd
        }

        if ev.state == .done || ev.state == .failed {
            appendRun(RunRecord(
                kind: .agent,
                title: resolvedTitle,
                cwd: resolvedCwd,
                exitCode: ev.state == .done ? 0 : 1,
                duration: max(0, now.timeIntervalSince(startedAt)),
                finishedAt: now
            ), into: &s)
        }

        s.agentSessions.sort { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            return lhs.updatedAt > rhs.updatedAt
        }
        if s.agentSessions.count > maxAgentSessions {
            s.agentSessions.removeLast(s.agentSessions.count - maxAgentSessions)
        }

        s.agentConflicts = AgentConflictDetector.detect(sessions: s.agentSessions, now: now)
        s.acknowledgedConflictIDs = s.acknowledgedConflictIDs.intersection(Set(s.agentConflicts.map(\.id)))
        recomputeReleaseReadiness(into: &s, at: now)

        var effects: [NotchEffect] = []
        if let confirmed = s.agentConflicts.first(where: { $0.confidence == .confirmed && !s.acknowledgedConflictIDs.contains($0.id) }) {
            s.acknowledgedConflictIDs.insert(confirmed.id)
            effects.append(contentsOf: post(Toast(
                key: "conflict:\(confirmed.id)",
                title: confirmed.title,
                subtitle: confirmed.detail,
                symbol: "exclamationmark.2",
                tint: .waiting,
                priority: .high,
                duration: .seconds(6)
            ), into: &s))
        }

        guard ev.state != .working else { return effects }

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
        return effects + post(toast, into: &s)
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

private extension NotchReducer {
    static func recordBuildEvent(_ input: BuildEventInput, at now: Date, into s: inout NotchState) -> [NotchEffect] {
        var normalized = input
        if normalized.timestamp == .distantPast {
            normalized.timestamp = now
        }
        guard let result = s.buildCorrelator.ingest(normalized) else {
            return []
        }

        s.latestBuildResult = result
        recomputeReleaseReadiness(into: &s, at: now)
        if let idx = s.buildHistory.firstIndex(where: { $0.id == result.id }) {
            s.buildHistory[idx] = result
        } else {
            s.buildHistory.insert(result, at: 0)
            if s.buildHistory.count > 10 {
                s.buildHistory.removeLast(s.buildHistory.count - 10)
            }
        }

        switch result.status {
        case .running:
            return []
        case .passed:
            let durationText = result.durationSeconds.map { String(format: "%.1fs", $0) }
            let subtitle = [result.toolchain.displayName, durationText].compactMap { $0 }.joined(separator: " · ")
            return post(Toast(
                key: result.toastKey,
                title: "\(result.project) \(result.kind == .test ? "tests passed" : "built")",
                subtitle: subtitle.isEmpty ? result.summary : subtitle,
                symbol: "checkmark.circle.fill",
                tint: .success,
                priority: .normal,
                duration: .seconds(3)
            ), into: &s)
        case .failed:
            let locPart = result.primaryLocation?.displayString
            let subtitle = [locPart, result.summary].compactMap { $0 }.joined(separator: " · ")
            return post(Toast(
                key: result.toastKey,
                title: "\(result.project) \(result.kind == .test ? "tests failed" : "build failed")",
                subtitle: subtitle,
                symbol: "xmark.octagon.fill",
                tint: .failure,
                priority: .high,
                duration: .seconds(8),
                errorLog: result.rawLogSnippet ?? result.summary
            ), into: &s)
        case .cancelled:
            return post(Toast(
                key: result.toastKey,
                title: "\(result.project) \(result.kind.rawValue) cancelled",
                subtitle: result.toolchain.displayName,
                symbol: "stop.circle.fill",
                tint: .waiting,
                priority: .normal,
                duration: .seconds(3)
            ), into: &s)
        case .unknown:
            return post(Toast(
                key: result.toastKey,
                title: "\(result.project) \(result.kind.rawValue) finished",
                subtitle: result.summary,
                symbol: "questionmark.circle.fill",
                tint: .neutral,
                priority: .normal,
                duration: .seconds(3)
            ), into: &s)
        }
    }

    private static func recomputeReleaseReadiness(into s: inout NotchState, at now: Date = Date()) {
        let hasSignal = s.latestBuildResult != nil
            || s.gitStatus != nil
            || !s.agentConflicts.isEmpty
            || !s.ciRuns.isEmpty
            || s.envGuardReport != nil
            || !s.dependencyFindings.isEmpty
        guard hasSignal else {
            s.releaseReadiness = nil
            return
        }
        s.releaseReadiness = ReleaseReadinessEvaluator.evaluate(
            latestBuild: s.latestBuildResult,
            gitStatus: s.gitStatus,
            agentConflicts: s.agentConflicts,
            ciRun: s.ciRuns.first,
            envReport: s.envGuardReport,
            securityFindings: s.dependencyFindings,
            now: now
        )
    }
}

