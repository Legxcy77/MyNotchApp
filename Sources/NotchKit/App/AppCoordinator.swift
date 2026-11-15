import AppKit
import SwiftUI

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
    private var dockerGlance: DockerGlanceMonitor?
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
    private var androidDropServer: AndroidDropServer?
    private var notifiedMeetingIDs: Set<String> = []
    private let lrclibClient = LRCLibClient()
    private let safariLyricsClient = SafariYouTubeMusicLyricsClient()
    private let lyricsCache = LyricsCache()
    private var lastLyricsTrackKey: String?
    private var lyricsTask: Task<Void, Never>?
    private var focusTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private let geminiClient = GeminiClient()
    private let worklogStore = DailyWorklogStore()
    private let faceAuthService = FaceAuthService()
    private var faceEnrollmentWindow: NSWindow?
    private var lockScreenController: LockScreenWindowController?
    private var mediaKeyHUDMonitor: MediaKeyHUDMonitor?
    private var airPodsBatteryMonitor: AirPodsBatteryMonitor?
    private var antigravityWatcher: AntigravityWatcher?
    private var widgetStudioController: WidgetStudioWindowController?
    private var powerSourceMonitor: PowerSourceMonitor?
    private var presenceMonitor: PresenceAutoLockMonitor?
    private var isMenuOpen = false

    init() {
        window = NotchWindowController(store: store)
        statusBar = StatusBarController(store: store, window: window, launchAtLogin: launchAtLogin, feedback: feedback)
        store.send(.worklogUpdated(worklogStore.load(range: .today)))
        store.onWorklogRangeChanged = { [weak self] range in
            guard let self else { return }
            self.store.send(.worklogUpdated(self.worklogStore.load(range: range)))
        }
        store.onClearWorklog = { [weak self] range in
            guard let self else { return }
            let dayKey: String
            switch range {
            case .yesterday:
                let yday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
                dayKey = DailyWorklogStore.dayKey(for: yday)
            case .specificDay(let key):
                dayKey = key
            default:
                dayKey = DailyWorklogStore.dayKey(for: .now)
            }
            self.worklogStore.clear(dayKey: dayKey)
            self.store.send(.worklogUpdated(self.worklogStore.load(range: range)))
        }
        store.onAction = { [weak self] action in
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
                Task { [weak self] in
                    let label = self?.store.state.devServers.first(where: { $0.pid == pid })?.label ?? "process"
                    _ = await self?.confirmAndKillProcess(pid: pid, processDescription: label)
                    await self?.devServers?.refreshOnce()
                }
            }
        }

        store.onToastShown = { [feedback] toast in
            feedback.play(for: toast)
        }

        let monitor = DevServerMonitor { [weak store] servers in
            store?.send(.devServersUpdated(servers))
        }
        devServers = monitor
        let dockerMonitor = DockerGlanceMonitor { [weak store] containers in
            store?.send(.dockerContainersUpdated(containers))
        }
        dockerGlance = dockerMonitor

        store.onModeChanged = { [weak self] mode in
            guard let self else { return }
            self.devServers?.setActive(mode == .expanded || self.isMenuOpen)
            Task { await self.dockerGlance?.setActive(mode == .expanded || self.isMenuOpen) }
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
            Task { await self.dockerGlance?.setActive(self.store.mode == .expanded || open) }
        }
        statusBar.onPinLogFile = { [weak self] path in
            self?.logPin?.pinFile(path: path)
            self?.store.post(Toast(title: "Pinned log", subtitle: (path as NSString).lastPathComponent, symbol: "pin.fill", tint: .info, duration: .seconds(2)))
        }
        statusBar.onUnpinLog = { [weak self] in
            self?.logPin?.unpin()
            self?.store.post(Toast(title: "Unpinned log", symbol: "pin.slash", tint: .neutral, duration: .seconds(2)))
        }
        statusBar.onSetupFaceUnlock = { [weak self] in
            self?.showFaceEnrollmentWindow()
        }
        statusBar.onScanFaceID = { [weak self] in
            self?.faceAuthService.startVerification { [weak self] in
                self?.store.post(Toast(
                    title: "Face ID Verified",
                    symbol: "faceid",
                    tint: .success,
                    duration: .seconds(2)
                ))
            }
        }
        statusBar.onSetAutoUnlockPassword = { [weak self] in
            self?.promptAndSaveAutoUnlockPassword()
        }
        statusBar.onLockScreen = { [weak self] in
            self?.lockScreenController?.lock()
        }
        statusBar.isAutoLockEnabled = { [weak self] in
            self?.lockScreenController?.autoLockOnSleepWake ?? true
        }
        statusBar.onToggleAutoLock = { [weak self] in
            self?.lockScreenController?.autoLockOnSleepWake.toggle()
        }
        statusBar.onOpenWidgetStudio = { [weak self] in
            self?.widgetStudioController?.show()
        }
        statusBar.onTriggerVoiceAI = { [weak self] in
            self?.triggerVoiceAI()
        }

        widgetStudioController = WidgetStudioWindowController(
            config: store.widgetConfig,
            onPreviewWidget: { [weak self] widget in
                self?.previewWidget(widget)
            }
        )

        let powerMon = PowerSourceMonitor { [weak self] snap in
            guard let self, self.store.widgetConfig.isEnabled(.hudMagSafePopup) else { return }
            let wattsText = snap.watts.map { " · \($0)W" } ?? ""
            self.store.post(Toast(
                key: "power:magsafe",
                title: "MagSafe Charging",
                subtitle: "\(snap.batteryPercent)%\(wattsText)",
                symbol: "bolt.fill",
                tint: .success,
                priority: .high,
                duration: .seconds(3),
                progress: Double(snap.batteryPercent) / 100.0
            ))
        }
        powerMon.start()
        powerSourceMonitor = powerMon

        let presMon = PresenceAutoLockMonitor(
            onCountdown: { [weak self] remaining in
                guard let self else { return }
                self.store.post(Toast(
                    key: "presence:autolock",
                    title: "ไม่พบใบหน้า · ล็อกใน \(remaining)s",
                    subtitle: "คลิกเพื่อยกเลิก",
                    symbol: "lock.rotation",
                    tint: .waiting,
                    priority: .high,
                    duration: .seconds(2)
                ))
            },
            onCancelCountdown: { [weak self] in
                self?.store.send(.dismissToast)
            },
            onTriggerLock: { [weak self] in
                self?.lockScreenController?.lock()
            }
        )
        presMon.configure(
            enabled: store.widgetConfig.isEnabled(.walkAwayAutoLock),
            thresholdSeconds: store.widgetConfig.walkAwayTimeoutSeconds
        )
        presenceMonitor = presMon

        lockScreenController = LockScreenWindowController(
            store: store,
            faceAuth: faceAuthService,
            onMediaCommand: { [weak self] command in
                self?.nowPlaying?.perform(command)
            }
        )
        faceAuthService.onEarStatusChanged = { [weak store] status in
            store?.send(.faceScanEarUpdated(status))
        }
        store.onServerAction = { [weak self] action in
            switch action {
            case .open(let s):
                NSWorkspace.shared.open(s.url)
            case .copy(let s):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s.url.absoluteString, forType: .string)
                self?.store.post(Toast(title: "Copied \(s.url.absoluteString)", symbol: "doc.on.doc", tint: .info, duration: .seconds(2)))
            case .copyPID(let s):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(s.pid)", forType: .string)
                self?.store.post(Toast(title: "Copied PID \(s.pid)", subtitle: s.processName, symbol: "number", tint: .info, duration: .seconds(2)))
            case .kill(let s):
                if s.isProtected {
                    self?.store.post(Toast(
                        title: "Protected process (PID \(s.pid))",
                        subtitle: "Cannot stop system or unknown process",
                        symbol: "lock.shield.fill",
                        tint: .waiting,
                        duration: .seconds(3)
                    ))
                    return
                }
                Task { [weak self] in
                    let desc = s.associatedProject.map { "\($0) (:\(s.port))" } ?? "\(s.label) (:\(s.port))"
                    _ = await self?.confirmAndKillProcess(pid: s.pid, processDescription: desc)
                    await self?.devServers?.refreshOnce()
                }
            }
        }
        store.onBuildAction = { [weak self] action in
            switch action {
            case .openLocation(let location):
                let url = URL(fileURLWithPath: location.file)
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.open(url)
                } else {
                    self?.store.post(Toast(
                        title: "File not found",
                        subtitle: location.displayString,
                        symbol: "doc.questionmark",
                        tint: .waiting,
                        duration: .seconds(2.5)
                    ))
                }
            case .copyError(let result):
                let text = result.rawLogSnippet ?? result.summary
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self?.store.post(Toast(
                    title: "Copied build log",
                    subtitle: result.project,
                    symbol: "doc.on.doc",
                    tint: .info,
                    duration: .seconds(2)
                ))
            }
        }
        store.onDockerAction = { [weak self] action in
            switch action {
            case .restart(let container):
                Task { [weak self] in
                    let ok = await self?.dockerGlance?.restartContainer(id: container.id) ?? false
                    await MainActor.run {
                        self?.store.post(Toast(
                            title: ok ? "Restarted \(container.name)" : "Restart failed",
                            symbol: "shippingbox.fill",
                            tint: ok ? .success : .failure,
                            duration: .seconds(2)
                        ))
                    }
                }
            case .pinLogs(let container):
                self?.logPin?.pinCommand("docker logs -f --tail 50 \(container.name)")
                self?.store.post(Toast(
                    title: "Pinned Docker logs",
                    subtitle: container.name,
                    symbol: "text.magnifyingglass",
                    tint: .info,
                    duration: .seconds(2)
                ))
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
        startAudioNotesAndAndroidDrop()
        startMediaKeyHUD()
    }

    private func startMediaKeyHUD() {
        let monitor = MediaKeyHUDMonitor { [weak self] toast in
            self?.store.post(toast)
        }
        monitor.start()
        mediaKeyHUDMonitor = monitor

        let btMonitor = AirPodsBatteryMonitor { [weak self] toast in
            self?.store.post(toast)
        }
        btMonitor.start()
        airPodsBatteryMonitor = btMonitor

        let agWatcher = AntigravityWatcher { [weak self] event in
            self?.handleIncomingActivity(event)
        }
        agWatcher.start()
        antigravityWatcher = agWatcher
    }

    private func startAudioNotesAndAndroidDrop() {
        let savedNotes = QuickNotesStore.load()
        if !savedNotes.note.isEmpty {
            store.send(.setQuickNote(savedNotes.note))
        }
        for task in savedNotes.tasks.reversed() {
            store.send(.addQuickTask(task.title))
            if task.isDone, let added = store.state.notesPayload.tasks.first {
                store.send(.toggleQuickTask(added.id))
            }
        }
        store.onNotesUpdated = { payload in
            QuickNotesStore.save(payload)
        }
        store.onAirDrop = { [weak self] urls in
            let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !existing.isEmpty,
                  let service = NSSharingService(named: .sendViaAirDrop),
                  service.canPerform(withItems: existing) else {
                self?.store.post(Toast(
                    title: "AirDrop unavailable",
                    subtitle: "Check file exists or Bluetooth/Wi-Fi",
                    symbol: "wave.3.up.circle",
                    tint: .failure,
                    duration: .seconds(2)
                ))
                return false
            }
            service.perform(withItems: existing)
            return true
        }

        store.send(.audioStateUpdated(AudioDeviceService.currentSnapshot()))
        store.onAudioAction = { [weak self] action in
            switch action {
            case .setVolume(let vol):
                AudioDeviceService.setVolume(vol)
            case .toggleMute:
                let current = AudioDeviceService.currentSnapshot().isMuted
                AudioDeviceService.setMuted(!current)
            case .selectDevice(let id):
                AudioDeviceService.setDefaultOutputDevice(id)
            case .refresh:
                break
            }
            self?.store.send(.audioStateUpdated(AudioDeviceService.currentSnapshot()))
        }

        let dropServer = AndroidDropServer(
            onStatusChange: { [weak self] status in
                self?.store.send(.androidDropUpdated(status))
            },
            onFilesReceived: { [weak self] urls in
                guard let self, let folder = urls.first?.deletingLastPathComponent() else { return }
                self.store.post(Toast(
                    title: "Received \(urls.count) file(s) from Android",
                    subtitle: urls.map(\.lastPathComponent).joined(separator: ", "),
                    symbol: "iphone.and.arrow.forward",
                    tint: .success,
                    duration: .seconds(5),
                    action: .openURL(folder)
                ))
            }
        )
        self.androidDropServer = dropServer
        store.onToggleAndroidDrop = { [weak self] in
            guard let self, let srv = self.androidDropServer else { return }
            if self.store.state.androidDrop.isRunning {
                srv.stop()
            } else {
                srv.updateStagedFiles(self.store.state.stagedFiles)
                srv.start()
            }
        }
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
        case .lockScreen:
            store.send(.hoverChanged(false))
            lockScreenController?.lock()
        case .toggleAutoLock:
            guard let controller = lockScreenController else { return }
            controller.autoLockOnSleepWake.toggle()
            let on = controller.autoLockOnSleepWake
            store.post(Toast(
                title: on ? "Auto-Lock ON" : "Auto-Lock OFF",
                subtitle: on ? "Locks on sleep/wake" : "Manual lock only (⌥⌘L)",
                symbol: on ? "lock.rotation" : "lock.open",
                tint: on ? .info : .neutral,
                duration: .seconds(2.5)
            ))
        case .setupFaceUnlock:
            store.send(.hoverChanged(false))
            showFaceEnrollmentWindow()
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
            let safariClient = self.safariLyricsClient
            let cache = self.lyricsCache
            let netEaseClient = NetEaseLyricsClient()
            self.lyricsTask = Task { [weak self] in
                guard !track.artist.isEmpty, !track.title.isEmpty else { return }
                var doc: LRCDocument?
                if let res = try? await cache.lyrics(
                    artist: track.artist,
                    track: track.title,
                    album: track.album,
                    duration: track.duration,
                    using: client
                ), !Task.isCancelled {
                    if let synced = res.syncedLyrics, !synced.isEmpty {
                        doc = LRCParser.parse(synced)
                    } else if let plain = res.plainLyrics, !plain.isEmpty {
                        doc = LRCParser.plain(
                            plain,
                            title: res.trackName,
                            artist: res.artistName,
                            album: res.albumName,
                            sourceLabel: "LRCLIB"
                        )
                    }
                }

                if doc == nil, !Task.isCancelled {
                    doc = try? await netEaseClient.fetchLyrics(
                        artist: track.artist,
                        track: track.title,
                        duration: track.duration
                    )
                }

                if doc == nil, !Task.isCancelled, track.source.localizedCaseInsensitiveContains("safari") {
                    var safariText = await safariClient.fetchLyrics()
                    if safariText == nil, !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(1200))
                        if !Task.isCancelled {
                            safariText = await safariClient.fetchLyrics()
                        }
                    }
                    if let safariText, !Task.isCancelled {
                        doc = LRCParser.plain(
                            safariText,
                            title: track.title,
                            artist: track.artist,
                            album: track.album,
                            sourceLabel: "YT MUSIC"
                        )
                    }
                }

                guard !Task.isCancelled, var resolvedDoc = doc else { return }
                let savedOffset = await cache.savedOffset(for: key)
                if abs(savedOffset) > 0.001 {
                    resolvedDoc = resolvedDoc.withOffset(savedOffset)
                }
                let finalDoc = resolvedDoc
                await MainActor.run { [weak self] in
                    guard let self, self.lastLyricsTrackKey == key else { return }
                    self.store.send(.lyricsUpdated(finalDoc))
                }
            }
        }
        service.start()
        nowPlaying = service
        store.onLyricsOffsetChanged = { [weak self] trackKey, offset in
            guard let cache = self?.lyricsCache else { return }
            Task {
                await cache.saveOffset(offset, for: trackKey)
            }
        }
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
        let monitor = GitGlanceMonitor { [weak self, weak store] status in
            store?.send(.gitStatusUpdated(status))
            self?.refreshRepoIntelligence(for: status)
        }
        gitGlance = monitor
    }

    private func refreshRepoIntelligence(for status: GitStatus?) {
        guard let status else {
            store.send(.changeImpactUpdated(nil))
            store.send(.envGuardUpdated(nil))
            store.send(.databaseReportUpdated(nil))
            return
        }
        let repoRoot = status.repoRoot
        let dirtyCount = status.dirtyCount
        Task.detached(priority: .utility) { [weak store] in
            let changedFiles: [String]
            if dirtyCount > 0 {
                let output = Self.execCommand("git diff --name-only HEAD", in: repoRoot).tailOutput
                changedFiles = output
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            } else {
                changedFiles = []
            }
            let impactReport = changedFiles.isEmpty
                ? nil
                : ChangeImpactAnalyzer.analyze(changedFiles: changedFiles, repoRoot: URL(fileURLWithPath: repoRoot))

            let envExampleURL = URL(fileURLWithPath: repoRoot).appendingPathComponent(".env.example")
            let envURL = URL(fileURLWithPath: repoRoot).appendingPathComponent(".env")
            let envReport: EnvGuardReport?
            if let exampleText = try? String(contentsOf: envExampleURL, encoding: .utf8) {
                let envText = (try? String(contentsOf: envURL, encoding: .utf8)) ?? ""
                envReport = EnvGuard.compare(exampleContent: exampleText, envContent: envText)
            } else {
                envReport = nil
            }

            let dbReport = DatabaseMigrationInspector.inspectLocalMigrations(in: URL(fileURLWithPath: repoRoot), appliedMigrations: nil)
            let visibleDBReport: DatabaseHealthReport?
            if case .available = dbReport.availability {
                visibleDBReport = dbReport
            } else {
                visibleDBReport = nil
            }

            await MainActor.run {
                store?.send(.changeImpactUpdated(impactReport))
                store?.send(.envGuardUpdated(envReport))
                store?.send(.databaseReportUpdated(visibleDBReport))
            }
        }
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
        hk.registerOptionCommandL { [weak self] in
            self?.lockScreenController?.toggleLock()
        }
        hk.registerOptionCommandU { [weak self] in
            self?.lockScreenController?.unlock()
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
                    if toast.tint == .success || toast.tint == .failure || toast.tint == .waiting {
                        self.recordWorklogEntry(WorklogEntry(
                            kind: toast.tint == .failure ? .command : .command,
                            title: toast.title,
                            detail: toast.subtitle,
                            exitCode: toast.tint == .failure ? 1 : (toast.tint == .success ? 0 : nil),
                            fingerprint: "toast:\(toast.key ?? toast.title):\(toast.tint.rawValue)"
                        ))
                    }
                case .activity(let ev):
                    self.handleIncomingActivity(ev)
                case .buildEvent(let input):
                    store.send(.buildEvent(input))
                    if let latest = store.state.latestBuildResult {
                        let kind: WorklogEntry.Kind = switch latest.status {
                        case .running: .buildRunning
                        case .passed: .buildPassed
                        case .failed, .cancelled, .unknown: .buildFailed
                        }
                        let detail = [latest.primaryLocation?.displayString, latest.summary].compactMap { $0 }.joined(separator: " · ")
                        let entry = WorklogEntry(
                            kind: kind,
                            title: "\(latest.project) \(latest.kind.rawValue) \(latest.status.rawValue)",
                            detail: detail,
                            project: latest.project,
                            duration: latest.durationSeconds,
                            exitCode: latest.exitCode,
                            fingerprint: "build:\(latest.id):\(latest.status.rawValue)"
                        )
                        self.recordWorklogEntry(entry)
                        if latest.status == .failed {
                            self.explainErrorInThai(
                                entryID: entry.id,
                                entryDate: entry.timestamp,
                                rawOutput: latest.rawLogSnippet ?? latest.summary,
                                toastKey: latest.toastKey,
                                toastTitle: "\(latest.project) \(latest.kind.rawValue) failed"
                            )
                        }
                    }
                case .terminalOutput(let term):
                    self.handleTerminalOutput(term)
                case .ciRunsUpdated(let runs):
                    store.send(.ciRunsUpdated(runs))
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

    private func promptAndSaveAutoUnlockPassword() {
        let alert = NSAlert()
        alert.messageText = "Auto-Unlock Password (Keychain)"
        alert.informativeText = "กรอกรหัสผ่านล็อกอิน Mac เพื่อใช้ปลดล็อก loginwindow อัตโนมัติเมื่อสแกนหน้าผ่าน (เก็บใน macOS Keychain เท่านั้น)"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Mac login password"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save to Keychain")
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let ok = SystemUnlockKeychain.savePassword(field.stringValue)
            store.post(Toast(
                title: ok ? "Auto-Unlock Password Saved" : "Failed to save password",
                symbol: "key.fill",
                tint: ok ? .success : .failure,
                duration: .seconds(2.5)
            ))
        } else if response == .alertSecondButtonReturn {
            SystemUnlockKeychain.deletePassword()
            store.post(Toast(
                title: "Auto-Unlock Password Cleared",
                symbol: "key.slash",
                tint: .neutral,
                duration: .seconds(2)
            ))
        }
    }

    private func showFaceEnrollmentWindow() {
        if let existing = faceEnrollmentWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let service = faceAuthService
        let view = FaceEnrollmentView(service: service) { [weak self] in
            self?.faceEnrollmentWindow?.close()
            self?.faceEnrollmentWindow = nil
        }
        let hosting = NSHostingController(rootView: view)
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .black
        panel.contentViewController = hosting
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        faceEnrollmentWindow = panel
    }

    private func triggerVoiceAI() {
        guard store.widgetConfig.isEnabled(.voiceAI) else { return }
        store.post(Toast(
            key: "voice:ai",
            title: "Voice-to-Notch AI",
            subtitle: "กำลังฟังคำสั่งเสียง...",
            symbol: "waveform.circle.fill",
            tint: .info,
            priority: .high,
            duration: .seconds(8)
        ))
        store.voiceService.toggleListening { [weak self] query, reply in
            guard let self else { return }
            self.store.post(Toast(
                key: "voice:ai",
                title: query,
                subtitle: reply,
                symbol: "sparkles",
                tint: .success,
                priority: .high,
                duration: .seconds(8)
            ))
        }
    }

    private func previewWidget(_ widget: WidgetID) {
        presenceMonitor?.configure(
            enabled: store.widgetConfig.isEnabled(.walkAwayAutoLock),
            thresholdSeconds: store.widgetConfig.walkAwayTimeoutSeconds
        )
        switch widget {
        case .hudVolumeBrightness:
            store.post(Toast(
                key: "hud:volume",
                title: "Volume",
                subtitle: "75%",
                symbol: "speaker.wave.2.fill",
                tint: .neutral,
                priority: .high,
                duration: .seconds(2),
                progress: 0.75
            ))
        case .hudAirPodsPopup, .bentoSpatial3D:
            store.post(Toast(
                key: "preview:airpods",
                title: "AirPods Pro",
                subtitle: "L 95% · R 95% · Case 80%",
                symbol: "airpodspro",
                tint: .info,
                priority: .high,
                duration: .seconds(3),
                progress: 0.95
            ))
        case .hudMagSafePopup:
            store.post(Toast(
                key: "power:magsafe",
                title: "MagSafe Charging",
                subtitle: "84% · 67W",
                symbol: "bolt.fill",
                tint: .success,
                priority: .high,
                duration: .seconds(3),
                progress: 0.84
            ))
        case .earsDevTicker, .bentoMissionControl:
            store.terminalTail.append("[PASS] 115 tests in 39 suites passed")
            store.post(Toast(
                key: "preview:mission",
                title: "swift test · 00:04",
                subtitle: "[PASS] 115 tests passed",
                symbol: "hammer.fill",
                tint: .success,
                priority: .normal,
                duration: .seconds(3)
            ))
        case .voiceAI:
            store.post(Toast(
                key: "voice:ai",
                title: "Voice-to-Notch AI",
                subtitle: "กด Voice-to-Notch AI จากเมนูเพื่อพูดสั่ง",
                symbol: "waveform.circle.fill",
                tint: .info,
                priority: .high,
                duration: .seconds(3)
            ))
        case .walkAwayAutoLock:
            store.post(Toast(
                key: "presence:autolock",
                title: "Walk-Away Auto-Lock",
                subtitle: "ไม่พบใบหน้า · ล็อกใน 3s",
                symbol: "lock.rotation",
                tint: .waiting,
                priority: .high,
                duration: .seconds(3)
            ))
        case .lockScreenCard, .lockScreenAurora:
            lockScreenController?.lock()
        default:
            store.post(Toast(
                key: "preview:\(widget.rawValue)",
                title: widget.title,
                subtitle: widget.subtitle,
                symbol: widget.symbol,
                tint: .info,
                priority: .normal,
                duration: .seconds(2.5)
            ))
        }
    }

    private func confirmAndKillProcess(pid: Int32, processDescription: String) async -> Bool {
        guard DevServerMonitor.isSafeToTerminate(pid: pid) else {
            store.post(Toast(
                title: "Blocked unsafe PID \(pid)",
                symbol: "hand.raised.fill",
                tint: .failure,
                priority: .high,
                duration: .seconds(3)
            ))
            return false
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Stop \(processDescription)?"
        alert.informativeText = "Send SIGTERM to PID \(pid) to stop this process gracefully."
        alert.addButton(withTitle: "Stop Process")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        let result = await DevServerMonitor.killServer(pid: pid)
        switch result {
        case .terminated:
            return true
        case .unsafePID, .permissionDenied:
            store.post(Toast(
                title: "Permission denied (PID \(pid))",
                subtitle: "Process belongs to another user or system",
                symbol: "lock.shield.fill",
                tint: .failure,
                priority: .high,
                duration: .seconds(4)
            ))
            return false
        case .notFound:
            store.post(Toast(
                title: "Process already exited (PID \(pid))",
                symbol: "info.circle",
                tint: .neutral,
                duration: .seconds(2.5)
            ))
            return true
        case .timedOut:
            store.post(Toast(
                title: "Process did not exit (PID \(pid))",
                subtitle: "Sent SIGTERM; process may still be shutting down.",
                symbol: "exclamationmark.triangle.fill",
                tint: .waiting,
                priority: .high,
                duration: .seconds(4)
            ))
            return false
        }
    }

    private func recordWorklogEntry(_ entry: WorklogEntry) {
        worklogStore.append(entry)
        store.send(.worklogUpdated(worklogStore.load(range: store.state.worklogRange)))
    }

    private func handleIncomingActivity(_ ev: ActivityEvent) {
        store.send(.recordActivity(ev, at: .now))
        if let cwd = ev.cwd, !cwd.isEmpty {
            store.send(.setActiveRepoPath(cwd))
            gitGlance?.watch(cwd: cwd)
        }
        let kind: WorklogEntry.Kind = switch ev.state {
        case .working: .agentWorking
        case .waiting: .agentWaiting
        case .done: .agentDone
        case .failed: .agentFailed
        }
        let project = ev.repo ?? ev.cwd.map { ($0 as NSString).lastPathComponent }
        let detail = ev.modifiedFiles.first.map { ($0 as NSString).lastPathComponent } ?? ev.cwd
        recordWorklogEntry(WorklogEntry(
            kind: kind,
            title: ev.title ?? "\(ev.source) \(ev.state.rawValue)",
            detail: detail,
            project: project,
            exitCode: ev.state == .done ? 0 : (ev.state == .failed ? 1 : nil),
            fingerprint: "activity:\(ev.source):\(ev.session):\(ev.state.rawValue):\(ev.title ?? "")"
        ))
    }

    private func handleTerminalOutput(_ term: TerminalOutputInput) {
        let parsed = TerminalOutputParser.parse(command: term.command, output: term.output, exitCode: term.exitCode)
        let project = term.project ?? parsed.toolchain.displayName

        switch parsed.kind {
        case .serverReady(let port, let url):
            let toast = Toast(
                key: "term:ready:\(port)",
                title: "\(project) พร้อมใช้งาน :\(port)",
                subtitle: url ?? term.command,
                symbol: "bolt.horizontal.circle.fill",
                tint: .success,
                priority: .normal,
                duration: .seconds(4),
                action: url.flatMap(URL.init(string:)).map { .openURL($0) }
            )
            store.post(toast)
            recordWorklogEntry(WorklogEntry(
                kind: .devServerReady,
                title: "\(project) listening :\(port)",
                detail: url ?? term.command,
                project: term.project,
                duration: term.durationSeconds,
                exitCode: 0,
                fingerprint: "term:ready:\(project):\(port)"
            ))

        case .error(let category, let summary, let location):
            let toastKey = "term:err:\(project):\(category)"
            let locText = location?.displayString
            let subtitle = [locText, summary].compactMap { $0 }.joined(separator: " · ")
            store.post(Toast(
                key: toastKey,
                title: "\(project) · \(category)",
                subtitle: subtitle,
                symbol: "xmark.octagon.fill",
                tint: .failure,
                priority: .high,
                duration: .seconds(8),
                errorLog: term.output.isEmpty ? summary : term.output
            ))
            let entry = WorklogEntry(
                kind: .devServerError,
                title: "\(project) · \(category)",
                detail: subtitle,
                project: term.project,
                duration: term.durationSeconds,
                exitCode: term.exitCode ?? 1,
                fingerprint: "term:err:\(project):\(summary)"
            )
            recordWorklogEntry(entry)
            explainErrorInThai(
                entryID: entry.id,
                entryDate: entry.timestamp,
                rawOutput: term.output.isEmpty ? summary : term.output,
                toastKey: toastKey,
                toastTitle: "\(project) · \(category)"
            )

        case .neutral:
            if let exitCode = term.exitCode {
                recordWorklogEntry(WorklogEntry(
                    kind: .command,
                    title: term.command,
                    detail: exitCode == 0 ? "Completed" : "exit \(exitCode)",
                    project: term.project,
                    duration: term.durationSeconds,
                    exitCode: exitCode
                ))
            }
        }
    }

    private func explainErrorInThai(
        entryID: UUID,
        entryDate: Date,
        rawOutput: String,
        toastKey: String?,
        toastTitle: String
    ) {
        guard let apiKey = GeminiKeychain.loadKey(), !apiKey.isEmpty else { return }
        let redacted = String(ErrorRedactor.redact(rawOutput).prefix(1_500))
        let prompt = """
        คุณคือผู้ช่วย Developer บน macOS
        วิเคราะห์ error ด้านล่างแล้วสรุปเป็น **ภาษาไทยล้วน สั้นกระชับ 1-2 ประโยค** (ไม่เกิน 140 ตัวอักษร) โดยบอก 1) สาเหตุ 2) จุดที่ต้องแก้:

        \(redacted)
        """
        let client = geminiClient
        Task { [weak self] in
            var buffer = ""
            do {
                try await client.streamResponse(prompt: prompt, apiKey: apiKey) { delta in
                    await MainActor.run {
                        buffer += delta
                    }
                }
                let explanation = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !explanation.isEmpty else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.worklogStore.updateAIExplanation(entryID: entryID, on: entryDate, explanation: explanation)
                    self.store.send(.worklogAIExplanationUpdated(id: entryID, explanation: explanation))
                    if let toastKey {
                        self.store.post(Toast(
                            key: toastKey,
                            title: toastTitle,
                            subtitle: explanation,
                            symbol: "sparkles",
                            tint: .failure,
                            priority: .high,
                            duration: .seconds(9),
                            errorLog: rawOutput
                        ))
                    }
                }
            } catch {
                // Non-fatal: deterministic error is already shown
            }
        }
    }
}

