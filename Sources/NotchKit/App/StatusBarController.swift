import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let store: NotchStore
    private let window: NotchWindowController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    init(store: NotchStore, window: NotchWindowController) {
        self.store = store
        self.window = window
        super.init()
        let image = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "MyNotchApp")
        image?.isTemplate = true
        item.button?.image = image
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(ActionMenuItem(title: "Show Island", on: window.isVisible) { [window] in
            window.setVisible(!window.isVisible)
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
