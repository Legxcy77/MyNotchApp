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
    let statusBar: StatusBarController
    private var eventBus: EventBusServer?
    private var devServers: DevServerMonitor?
    private var screenshots: ScreenshotWatcher?
    private var clipboard: ClipboardMonitor?
    private var hotKey: HotKeyMonitor?
    private var gitGlance: GitGlanceMonitor?
    private var logPin: LogPinMonitor?
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
            }
        }
        window = NotchWindowController(store: store)
        statusBar = StatusBarController(store: store, window: window, launchAtLogin: launchAtLogin)

        let monitor = DevServerMonitor { [weak store] servers in
            store?.send(.devServersUpdated(servers))
        }
        devServers = monitor

        store.onModeChanged = { [weak self] mode in
            guard let self else { return }
            self.devServers?.setActive(mode == .expanded || self.isMenuOpen)
            self.window.setClipboardFocus(mode == .clipboard || mode == .commandPalette)
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
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("Explain this error:\n\n\(log)", forType: .string)
                self?.store.send(.closeErrorLens)
                self?.store.post(Toast(
                    title: "Error prompt copied",
                    subtitle: "Ready for Quick AI (A6)",
                    symbol: "sparkles",
                    tint: .info,
                    duration: .seconds(3)
                ))
            }
        }

        startEventBus()
        startScreenshotWatcher()
        startClipboard()
        startGitGlance()
        startLogPin()
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

