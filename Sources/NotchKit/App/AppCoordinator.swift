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

    init() {
        window = NotchWindowController(store: store)
        statusBar = StatusBarController(store: store, window: window, launchAtLogin: launchAtLogin)
        startEventBus()
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
                    let (symbol, tint, priority): (String, Toast.Tint, Toast.Priority) = switch ev.state {
                    case .working: ("gearshape.2.fill", .info, .low)
                    case .waiting: ("hand.raised.fill", .waiting, .critical)
                    case .done: ("checkmark", .success, .normal)
                    case .failed: ("xmark", .failure, .high)
                    }
                    let subtitle = [ev.source, ev.cwd.map { ($0 as NSString).lastPathComponent }]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    store.post(Toast(
                        key: "activity:\(ev.source):\(ev.session)",
                        title: ev.title ?? "\(ev.source) \(ev.state.rawValue)",
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        symbol: symbol,
                        tint: tint,
                        priority: priority
                    ))
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

