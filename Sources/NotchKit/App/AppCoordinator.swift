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
            self.window.setClipboardFocus(mode == .clipboard)
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
        statusBar.onMenuVisibilityChanged = { [weak self] open in
            guard let self else { return }
            self.isMenuOpen = open
            self.devServers?.setActive(self.store.mode == .expanded || open)
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

        startEventBus()
        startScreenshotWatcher()
        startClipboard()
    }

    private func startClipboard() {
        let monitor = ClipboardMonitor { [weak store] content, date in
            store?.send(.clipboardRecorded(content, at: date))
        }
        monitor.start()
        clipboard = monitor

        let hk = HotKeyMonitor { [weak store] in
            store?.send(.toggleClipboard)
        }
        hk.registerOptionCommandV()
        hotKey = hk
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

