import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let store: NotchStore
    private let window: NotchWindowController
    private let launchAtLogin: LaunchAtLoginService
    private let feedback: FeedbackService
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    var onMenuVisibilityChanged: (@MainActor (Bool) -> Void)?
    var onPinLogFile: (@MainActor (String) -> Void)?
    var onUnpinLog: (@MainActor () -> Void)?

    init(store: NotchStore, window: NotchWindowController, launchAtLogin: LaunchAtLoginService, feedback: FeedbackService) {
        self.store = store
        self.window = window
        self.launchAtLogin = launchAtLogin
        self.feedback = feedback
        super.init()
        let image = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "MyNotchApp")
        image?.isTemplate = true
        item.button?.image = image
        menu.delegate = self
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        onMenuVisibilityChanged?(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        onMenuVisibilityChanged?(false)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(ActionMenuItem(title: "Show Island", on: window.isVisible) { [window] in
            window.setVisible(!window.isVisible)
        })
        menu.addItem(ActionMenuItem(title: "Clipboard History (⌥⌘V)") { [store] in
            store.send(.toggleClipboard)
        })
        menu.addItem(ActionMenuItem(title: "Command Palette (⌥Space)") { [store] in
            store.send(.toggleCommandPalette)
        })

        let displays = NSMenu()
        displays.addItem(ActionMenuItem(title: "Automatic", on: window.pinnedDisplayID == nil) { [window] in
            window.pinnedDisplayID = nil
        })
        displays.addItem(.separator())
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            let name = screen.localizedName + (screen.metrics.hasNotch ? "  (notch)" : "")
            displays.addItem(ActionMenuItem(title: name, on: window.pinnedDisplayID == id) { [window] in
                window.pinnedDisplayID = id
            })
        }
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displays
        menu.addItem(displayItem)

        menu.addItem(.separator())
        let debug = NSMenu()
        for (title, toast) in Self.debugToasts {
            debug.addItem(ActionMenuItem(title: title) { [store] in store.post(toast()) })
        }
        debug.addItem(ActionMenuItem(title: "Burst (queue + preempt)") { [store] in
            Self.debugToasts.forEach { store.post($0.1()) }
        })
        let debugItem = NSMenuItem(title: "Test Toasts", action: nil, keyEquivalent: "")
        debugItem.submenu = debug
        menu.addItem(debugItem)

        let serversMenu = NSMenu()
        if store.state.devServers.isEmpty {
            let empty = NSMenuItem(title: "No listening ports", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            serversMenu.addItem(empty)
        } else {
            for s in store.state.devServers {
                let sub = NSMenu()
                sub.addItem(ActionMenuItem(title: "Open localhost:\(s.port)") { [store] in store.perform(.open(s)) })
                sub.addItem(ActionMenuItem(title: "Copy URL") { [store] in store.perform(.copy(s)) })
                sub.addItem(.separator())
                sub.addItem(ActionMenuItem(title: "Kill (PID \(s.pid))") { [store] in store.perform(.kill(s)) })
                let row = NSMenuItem(title: ":\(s.port)  \(s.label)", action: nil, keyEquivalent: "")
                row.submenu = sub
                serversMenu.addItem(row)
            }
        }
        let serversItem = NSMenuItem(title: "Dev Servers", action: nil, keyEquivalent: "")
        serversItem.submenu = serversMenu
        menu.addItem(serversItem)

        let logMenu = NSMenu()
        logMenu.addItem(ActionMenuItem(title: "Pin Log File…") { [weak self] in
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                self?.onPinLogFile?(url.path)
            }
        })
        logMenu.addItem(ActionMenuItem(title: "Unpin") { [weak self] in
            self?.onUnpinLog?()
        })
        let logItem = NSMenuItem(title: "Log Pin", action: nil, keyEquivalent: "")
        logItem.submenu = logMenu
        menu.addItem(logItem)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Sound on Toasts", on: feedback.isSoundEnabled) { [feedback] in
            feedback.isSoundEnabled.toggle()
        })
        menu.addItem(ActionMenuItem(title: "Haptic on Alerts", on: feedback.isHapticEnabled) { [feedback] in
            feedback.isHapticEnabled.toggle()
        })
        let launchItem = ActionMenuItem(
            title: launchAtLogin.isBundledApp ? "Launch at Login" : "Launch at Login (requires .app)",
            on: launchAtLogin.isEnabled
        ) { [launchAtLogin, store] in
            do {
                try launchAtLogin.toggle()
            } catch {
                store.post(Toast(
                    title: "Launch at Login failed",
                    subtitle: error.localizedDescription,
                    symbol: "exclamationmark.triangle.fill",
                    tint: .failure,
                    priority: .high
                ))
            }
        }
        launchItem.isEnabled = launchAtLogin.isBundledApp
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Quit MyNotchApp", key: "q") { NSApp.terminate(nil) })
    }

    private static let debugToasts: [(String, @Sendable () -> Toast)] = [
        ("Build passed", { Toast(title: "Build succeeded", subtitle: "swift build · 4.9s", symbol: "checkmark", tint: .success) }),
        ("Tests failed", { Toast(title: "3 tests failed", subtitle: "dotnet test · 12.4s", symbol: "xmark", tint: .failure, priority: .high, duration: .seconds(5)) }),
        ("Agent waiting", { Toast(title: "Claude Code needs input", subtitle: "MyNotchApp · approve edit?", symbol: "hand.raised.fill", tint: .waiting, priority: .critical, duration: .seconds(6)) }),
        ("Info", { Toast(title: "localhost:5173 is up", subtitle: "vite", symbol: "network", tint: .info) }),
    ]
}

/// NSMenuItem with a closure instead of target/action boilerplate.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, on: Bool = false, key: String = "", handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
        state = on ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler() }
}

