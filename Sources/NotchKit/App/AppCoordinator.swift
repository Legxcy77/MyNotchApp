import AppKit

@MainActor
public final class NotchAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Composition root. New services get created and wired to the store here.
@MainActor
final class AppCoordinator {
    let store = NotchStore()
    let window: NotchWindowController
    let launchAtLogin = LaunchAtLoginService()
    let feedback = FeedbackService()
    let statusBar: StatusBarController
    private var eventBus: EventBusServer?
    private var devServers: DevServerMonitor?
    private var screenshots: ScreenshotWatcher?
    private var clipboard: ClipboardMonitor?
    private var hotKey: HotKeyMonitor?
    private var gitGlance: GitGlanceMonitor?
    private var logPin: LogPinMonitor?
    private var nowPlaying: NowPlayingService?
    private var meetingMonitor: MeetingMonitor?
    private var githubMonitor: GitHubPulseMonitor?
    private var systemPulseMonitor: SystemPulseMonitor?
    private var keyboardStatusMonitor: KeyboardStatusMonitor?
    private var notifiedMeetingIDs: Set<String> = []
    private let lrclibClient = LRCLibClient()
    private let lyricsCache = LyricsCache()
    private var lastLyricsTrackKey: String?
    private var lyricsTask: Task<Void, Never>?
    private var focusTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private let geminiClient = GeminiClient()
    private var isMenuOpen = false

    init() {
        store.onAction = { action in
            switch action {
            case .activateApp(let bundleID):
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                    app.activate()
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            case .openURL(let url):
                NSWorkspace.shared.open(url)
            case .killProcess(let pid):
                Task {
                    await DevServerMonitor.killServer(pid: pid)
                }
            }
        }
        window = NotchWindowController(store: store)
        statusBar = StatusBarController(store: store, window: window, launchAtLogin: launchAtLogin, feedback: feedback)

        store.onToastShown = { [feedback] toast in
            feedback.play(for: toast)
        }

        let monitor = DevServerMonitor { [weak store] servers in
            store?.send(.devServersUpdated(servers))
        }
        devServers = monitor

        store.onModeChanged = { [weak self] mode in
            guard let self else { return }
            self.devServers?.setActive(mode == .expanded || self.isMenuOpen)
            self.window.setClipboardFocus(mode == .clipboard || mode == .commandPalette || mode == .quickAI)
            if mode == .commandPalette {
                let repo = self.resolvedRepoPath()
                self.store.send(.setActiveRepoPath(repo))
                let tasks = RepoTaskScanner.scan(repoPath: repo)
                self.store.send(.repoTasksUpdated(tasks))
            }
        }
        store.onRunTask = { [weak self] task in
            guard let self else { return }
            self.store.send(.setCommandPaletteOpen(false))
            let repo = self.resolvedRepoPath()
            self.runTaskInBackground(task, repoPath: repo)
        }
        store.onAskAI = { [weak self] prompt in
            self?.runQuickAI(prompt: prompt)
        }
        store.onMediaCommand = { [weak self] command in
            self?.nowPlaying?.perform(command)
        }
        store.onQuickTool = { [weak self] action in
            self?.handleQuickTool(action)
        }
        store.onFocusChanged = { [weak self] session in
            self?.handleFocusChanged(session)
        }
        store.onPasteClipboard = { [weak self] item in
            guard let self else { return }
            self.store.send(.setClipboardOpen(false))
            let pasted = self.clipboard?.writeAndPaste(item, targetApp: self.window.previousApp) ?? false
            if !pasted {
                self.store.post(Toast(
                    title: "Copied to clipboard",
                    subtitle: "Grant Accessibility in System Settings for auto-paste",
                    symbol: "doc.on.clipboard",
                    tint: .info,
                    duration: .seconds(4)
                ))
            }
        }
        store.onCopyText = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.store.send(.setClipboardOpen(false))
            self?.store.post(Toast(title: "Copied transformed value", symbol: "doc.on.doc", tint: .info, duration: .seconds(2)))
        }
        statusBar.onMenuVisibilityChanged = { [weak self] open in
            guard let self else { return }
            self.isMenuOpen = open
            self.devServers?.setActive(self.store.mode == .expanded || open)
        }
        statusBar.onPinLogFile = { [weak self] path in
            self?.logPin?.pinFile(path: path)
            self?.store.post(Toast(title: "Pinned log", subtitle: (path as NSString).lastPathComponent, symbol: "pin.fill", tint: .info, duration: .seconds(2)))
        }
        statusBar.onUnpinLog = { [weak self] in
            self?.logPin?.unpin()
            self?.store.post(Toast(title: "Unpinned log", symbol: "pin.slash", tint: .neutral, duration: .seconds(2)))
        }
        store.onServerAction = { [weak self] action in
            switch action {
            case .open(let s):
                NSWorkspace.shared.open(s.url)
            case .copy(let s):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s.url.absoluteString, forType: .string)
                self?.store.post(Toast(title: "Copied \(s.url.absoluteString)", symbol: "doc.on.doc", tint: .info, duration: .seconds(2)))
            case .kill(let s):
                Task { [weak self] in
                    await DevServerMonitor.killServer(pid: s.pid)
                    await self?.devServers?.refreshOnce()
                }
            }
        }
        store.onErrorAction = { [weak self] action in
            switch action {
            case .copy(let log):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(log, forType: .string)
                self?.store.send(.closeErrorLens)
                self?.store.post(Toast(title: "Copied error log", symbol: "doc.on.doc", tint: .info, duration: .seconds(2)))
            case .askAI(let log):
                self?.store.send(.closeErrorLens)
                let prompt = "Explain this error and how to fix it:\n\n\(log)"
                self?.store.send(.setAIPrompt(prompt))
                self?.store.send(.setQuickAIOpen(true))
                self?.runQuickAI(prompt: prompt)
            }
        }

        startEventBus()
        startScreenshotWatcher()
        startClipboard()
        startGitGlance()
        startLogPin()
        startNowPlaying()
        startMeetingMonitor()
        startGitHubPulse()
        startSystemPulse()
        startKeyboardStatus()
    }

    private func runQuickAI(prompt: String) {
        aiTask?.cancel()
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.send(.appendAIChatMessage(AIChatMessage(role: .user, text: trimmed)))
        store.send(.setAIPrompt(""))

        guard let apiKey = GeminiKeychain.loadKey() else {
            store.send(.appendAIChatMessage(AIChatMessage(role: .model, text: "Please enter your Gemini API key above.")))
            return
        }

        let historySnapshot = store.state.aiMessages
        store.send(.appendAIChatMessage(AIChatMessage(role: .model, text: "")))
        store.send(.updateLastAIChatMessage("", isLoading: true))

        let client = geminiClient
        let storeRef = store
        aiTask = Task { [weak storeRef] in
            do {
                try await client.streamChat(messages: historySnapshot, apiKey: apiKey) { delta in
                    await MainActor.run {
                        guard let storeRef else { return }
                        storeRef.send(.updateLastAIChatMessage(storeRef.state.aiResponse + delta, isLoading: true))
                    }
                }
                await MainActor.run {
                    guard let storeRef else { return }
                    storeRef.send(.updateLastAIChatMessage(storeRef.state.aiResponse, isLoading: false))
                }
            } catch {
                await MainActor.run {
                    storeRef?.send(.updateLastAIChatMessage("Error: \(error.localizedDescription)", isLoading: false))
                }
            }
        }
    }

    private func handleFocusChanged(_ session: FocusSession?) {
        focusTask?.cancel()
        focusTask = nil

        if let shortcutName = UserDefaults.standard.string(forKey: "notch.focusShortcut"), !shortcutName.isEmpty {
            Task.detached(priority: .utility) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                p.arguments = ["run", shortcutName]
                p.standardOutput = Pipe()
                p.standardError = Pipe()
                try? p.run()
            }
        }

        guard let session else { return }
        let seconds = session.duration
        focusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.store.send(.stopFocus)
            self.store.post(Toast(
                title: "Focus complete",
                subtitle: "\(Int(seconds / 60))m session finished",
                symbol: "checkmark.circle.fill",
                tint: .success,
                priority: .high,
                duration: .seconds(6)
            ))
        }
    }

    private func startKeyboardStatus() {
        let monitor = KeyboardStatusMonitor { [weak store] toast in
            store?.post(toast)
        }
        monitor.start()
        keyboardStatusMonitor = monitor
    }

    private func handleQuickTool(_ action: NotchStore.QuickToolAction) {
        switch action {
        case .ocr:
            store.send(.hoverChanged(false))
            QuickToolsService.ocrScreenRegion { [weak store] text in
                guard let text else { return }
                store?.post(Toast(title: "OCR copied", subtitle: text.replacingOccurrences(of: "\n", with: " "), symbol: "text.viewfinder", tint: .success, duration: .seconds(3)))
            }
        case .colorPicker:
            store.send(.hoverChanged(false))
            QuickToolsService.pickColor { [weak store] hex in
                guard let hex else { return }
                store?.post(Toast(title: "Copied \(hex)", symbol: "eyedropper", tint: .info, duration: .seconds(3)))
            }
        case .screenshotArea:
            store.send(.hoverChanged(false))
            QuickToolsService.captureScreenshot(interactive: true)
        case .screenshotFull:
            store.send(.hoverChanged(false))
            QuickToolsService.captureScreenshot(interactive: false)
        case .transformClipboard(let kind):
            let latest = store.state.clipboard.items.compactMap { item -> String? in
                if case .text(let t) = item.content { return t }
                return nil
            }.first ?? NSPasteboard.general.string(forType: .string) ?? ""
            guard !latest.isEmpty else { return }
            let transformed = TextTransformer.transform(latest, kind)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transformed, forType: .string)
            store.post(Toast(title: "Transformed (\(kind.rawValue))", subtitle: transformed, symbol: "textformat", tint: .success, duration: .seconds(2)))
        case .openCommandPalette:
            store.send(.hoverChanged(false))
            store.send(.setCommandPaletteOpen(true))
        case .openQuickAI:
            store.send(.hoverChanged(false))
            store.send(.setQuickAIOpen(true))
        case .openClipboard:
            store.send(.hoverChanged(false))
            store.send(.setClipboardOpen(true))
        }
    }

    private func startSystemPulse() {
        let monitor = SystemPulseMonitor { [weak self] samples, hotAlert in
            guard let self else { return }
            self.store.send(.systemPulseUpdated(samples))
            if let hot = hotAlert {
                self.store.post(Toast(
                    key: "cpu:\(hot.pid)",
                    title: "\(hot.name) using \(Int(hot.cpuPercent))% CPU",
                    subtitle: "PID \(hot.pid) >90% for 30s · Click to kill",
                    symbol: "flame.fill",
                    tint: .failure,
                    priority: .high,
                    duration: .seconds(8),
                    action: .killProcess(pid: hot.pid)
                ))
            }
        }
        monitor.start()
        systemPulseMonitor = monitor
    }

    private func startGitHubPulse() {
        let monitor = GitHubPulseMonitor { [weak self] _, changes in
            guard let self else { return }
            for pr in changes {
                self.store.post(Toast(
                    key: "gh:\(pr.id)",
                    title: pr.isReviewRequest ? "Review requested" : "PR #\(pr.number) updated",
                    subtitle: "\(pr.repo) · \(pr.title)",
                    symbol: "arrow.triangle.pull",
                    tint: pr.checksState == .failing ? .failure : .info,
                    priority: pr.isReviewRequest ? .high : .normal,
                    duration: .seconds(5),
                    action: .openURL(pr.url)
                ))
            }
        }
        monitor.start()
        githubMonitor = monitor
    }

    private func startMeetingMonitor() {
        let monitor = MeetingMonitor { [weak self] meeting in
            guard let self else { return }
            self.store.send(.nextMeetingUpdated(meeting))
            if let meeting,
               MeetingDetector.isWithinCountdownWindow(meeting),
               !self.notifiedMeetingIDs.contains(meeting.id) {
                self.notifiedMeetingIDs.insert(meeting.id)
                let countdown = MeetingDetector.countdownText(until: meeting.startDate)
                self.store.post(Toast(
                    key: "meeting:\(meeting.id)",
                    title: meeting.title,
                    subtitle: countdown == "NOW" ? "Meeting started · Click to join" : "Starts in \(countdown) · Click to join",
                    symbol: "video.fill",
                    tint: .waiting,
                    priority: .high,
                    duration: .seconds(6),
                    action: .openURL(meeting.joinURL)
                ))
            }
        }
        monitor.start()
        meetingMonitor = monitor
    }

    private func startNowPlaying() {
        let service = NowPlayingService { [weak self] track in
            guard let self else { return }
            self.store.send(.nowPlayingUpdated(track))

            guard let track else {
                self.lastLyricsTrackKey = nil
                self.lyricsTask?.cancel()
                self.store.send(.lyricsUpdated(nil))
                return
            }

            let key = track.trackKey
            guard key != self.lastLyricsTrackKey else { return }
            self.lastLyricsTrackKey = key
            self.store.send(.lyricsUpdated(nil))
            self.lyricsTask?.cancel()

            let client = self.lrclibClient
            let cache = self.lyricsCache
            self.lyricsTask = Task { [weak self] in
                guard !track.artist.isEmpty, !track.title.isEmpty else { return }
                if let res = try? await cache.lyrics(
                    artist: track.artist,
                    track: track.title,
                    album: track.album,
                    duration: track.duration,
                    using: client
                ), !Task.isCancelled {
                    let doc: LRCDocument?
                    if let synced = res.syncedLyrics, !synced.isEmpty {
                        doc = LRCParser.parse(synced)
                    } else if let plain = res.plainLyrics, !plain.isEmpty {
                        let plainLines = plain
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .enumerated()
                            .map { LRCLine(id: $0.offset, time: 0, text: $0.element) }
                        doc = LRCDocument(title: res.trackName, artist: res.artistName, album: res.albumName, lines: plainLines)
                    } else {
                        doc = nil
                    }
                    await MainActor.run { [weak self] in
                        guard let self, self.lastLyricsTrackKey == key else { return }
                        self.store.send(.lyricsUpdated(doc))
                    }
                }
            }
        }
        service.start()
        nowPlaying = service
    }

    private func startLogPin() {
        let monitor = LogPinMonitor { [weak store] label, line in
            store?.post(Toast(
                key: "logpin:\(label)",
                title: "Log alert · \(label)",
                subtitle: line,
                symbol: "exclamationmark.octagon.fill",
                tint: .failure,
                priority: .high,
                duration: .seconds(4)
            ))
        }
        logPin = monitor
    }

    private func startGitGlance() {
        let monitor = GitGlanceMonitor { [weak store] status in
            store?.send(.gitStatusUpdated(status))
        }
        gitGlance = monitor
    }

    private func startClipboard() {
        let monitor = ClipboardMonitor { [weak store] content, date in
            store?.send(.clipboardRecorded(content, at: date))
        }
        monitor.start()
        clipboard = monitor

        let hk = HotKeyMonitor()
        hk.registerOptionCommandV { [weak store] in
            store?.send(.toggleClipboard)
        }
        hk.registerOptionSpace { [weak store] in
            store?.send(.toggleCommandPalette)
        }
        hk.registerOptionA { [weak store] in
            store?.send(.toggleQuickAI)
        }
        hotKey = hk
    }

    private func resolvedRepoPath() -> String {
        store.state.activeRepoPath
            ?? store.state.gitStatus?.repoRoot
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MyNotchApp").path
    }

    private func runTaskInBackground(_ task: RepoTask, repoPath: String) {
        store.post(Toast(
            key: "task:\(task.id)",
            title: "Running \(task.command)",
            subtitle: (repoPath as NSString).lastPathComponent,
            symbol: "terminal",
            tint: .info,
            duration: .seconds(15)
        ))

        Task { [weak store] in
            let start = ContinuousClock.now
            let result = await Task.detached(priority: .userInitiated) {
                Self.execCommand(task.command, in: repoPath)
            }.value
            let elapsed = ContinuousClock.now - start
            let durationSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let secs = Int(elapsed.components.seconds)

            store?.send(.recordRun(RunRecord(
                kind: .command,
                title: task.command,
                cwd: repoPath,
                exitCode: result.exitCode,
                duration: durationSeconds,
                finishedAt: .now
            )))

            if result.exitCode == 0 {
                store?.post(Toast(
                    key: "task:\(task.id)",
                    title: "Command finished",
                    subtitle: "\(task.command) · \(secs)s",
                    symbol: "checkmark",
                    tint: .success,
                    duration: .seconds(4)
                ))
            } else {
                store?.post(Toast(
                    key: "task:\(task.id)",
                    title: "Command failed (exit \(result.exitCode))",
                    subtitle: "\(task.command) · \(secs)s",
                    symbol: "xmark",
                    tint: .failure,
                    priority: .high,
                    duration: .seconds(8),
                    errorLog: result.tailOutput.isEmpty ? nil : result.tailOutput
                ))
            }
        }
    }

    private nonisolated static func execCommand(_ command: String, in directory: String) -> (exitCode: Int32, tailOutput: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", command]
        p.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            let tail = text.split(whereSeparator: \.isNewline).suffix(30).joined(separator: "\n")
            return (p.terminationStatus, tail)
        } catch {
            return (1, error.localizedDescription)
        }
    }

    private func startScreenshotWatcher() {
        let watcher = ScreenshotWatcher { [weak store] url in
            guard let store else { return }
            store.send(.stageFiles([url]))
            store.post(Toast(
                title: "Screenshot staged",
                subtitle: url.lastPathComponent,
                symbol: "camera.viewfinder",
                tint: .info,
                duration: .seconds(3),
                thumbnailPath: url.path
            ))
        }
        watcher.start()
        screenshots = watcher
    }

    private func startEventBus() {
        do {
            let token = try TokenStore.loadOrCreate()
            let server = EventBusServer(token: token) { [weak store] action in
                guard let store else { return }
                switch action {
                case .postToast(let toast):
                    store.post(toast)
                case .activity(let ev):
                    store.send(.recordActivity(ev, at: .now))
                    if let cwd = ev.cwd, !cwd.isEmpty {
                        store.send(.setActiveRepoPath(cwd))
                        self.gitGlance?.watch(cwd: cwd)
                    }
                case .pinLogFile(let path, let pattern):
                    self.logPin?.pinFile(path: path, pattern: pattern)
                    store.post(Toast(title: "Pinned log", subtitle: (path as NSString).lastPathComponent, symbol: "pin.fill", tint: .info, duration: .seconds(2)))
                case .pinLogCommand(let command, let pattern):
                    self.logPin?.pinCommand(command, pattern: pattern)
                    store.post(Toast(title: "Pinned command", subtitle: command, symbol: "pin.fill", tint: .info, duration: .seconds(2)))
                case .unpinLog:
                    self.logPin?.unpin()
                }
            }
            try server.start()
            eventBus = server
        } catch {
            store.post(Toast(
                title: "Event Bus failed",
                subtitle: error.localizedDescription,
                symbol: "exclamationmark.triangle.fill",
                tint: .failure,
                priority: .high
            ))
        }
    }
}

