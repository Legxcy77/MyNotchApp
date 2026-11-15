import AppKit
import SwiftUI

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var metrics: ScreenMetrics {
        ScreenMetrics(frame: frame,
                      safeAreaTop: safeAreaInsets.top,
                      auxiliaryTopLeft: auxiliaryTopLeftArea,
                      auxiliaryTopRight: auxiliaryTopRightArea)
    }
}

/// Owns the panel: which screen, where, and whether the mouse is over the island.
@MainActor
final class NotchWindowController {
    private let store: NotchStore
    private let panel: NotchPanel
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []

    /// nil = automatic (built-in notch screen, else main).
    var pinnedDisplayID: CGDirectDisplayID? {
        didSet {
            if let id = pinnedDisplayID {
                UserDefaults.standard.set(Int(id), forKey: "pinnedDisplayID")
            } else {
                UserDefaults.standard.removeObject(forKey: "pinnedDisplayID")
            }
            reposition()
        }
    }

    private(set) var isVisible = true
    private(set) var previousApp: NSRunningApplication?

    init(store: NotchStore) {
        self.store = store
        self.panel = NotchPanel(size: IslandLayout.panelSize)
        if let saved = UserDefaults.standard.object(forKey: "pinnedDisplayID") as? Int {
            pinnedDisplayID = CGDirectDisplayID(saved)
        }

        let container = DropTargetView(frame: NSRect(origin: .zero, size: IslandLayout.panelSize), store: store)
        let host = NSHostingView(rootView: NotchRootView(store: store))
        host.sizingOptions = [] // never let SwiftUI resize the panel
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container

        reposition()
        panel.orderFrontRegardless()
        startObserving()
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func setClipboardFocus(_ active: Bool) {
        if active {
            if let front = NSWorkspace.shared.frontmostApplication,
               front.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp = front
            }
            panel.allowsKeyWindow = true
            panel.ignoresMouseEvents = false
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.allowsKeyWindow = false
            panel.resignKey()
        }
    }

    var currentScreen: NSScreen? {
        let screens = NSScreen.screens
        if let id = pinnedDisplayID, let s = screens.first(where: { $0.displayID == id }) { return s }
        let mainIndex = NSScreen.main.flatMap { m in screens.firstIndex(of: m) }
        return ScreenGeometry.preferredIndex(in: screens.map(\.metrics), mainIndex: mainIndex).map { screens[$0] }
    }

    func reposition() {
        guard let screen = currentScreen else { return }
        let geometry = ScreenGeometry.resolve(screen.metrics)
        store.geometry = geometry
        let size = IslandLayout.panelSize
        panel.setFrame(NSRect(x: geometry.midX - size.width / 2,
                              y: geometry.screenTop - size.height,
                              width: size.width, height: size.height),
                       display: true)
    }

    // MARK: - Hover & hit-testing

    private func startObserving() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover() }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHover() }
            return event
        }) { monitors.append(l) }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.orderFrontRegardless() }
        })
    }

    private func updateHover() {
        guard isVisible else { return }
        if store.mode == .clipboard {
            if panel.ignoresMouseEvents { panel.ignoresMouseEvents = false }
            return
        }
        let rect = IslandLayout.hitRect(
            for: store.mode,
            geometry: store.geometry,
            hasActiveAgents: store.state.hasActiveAgents
        )
        let inside = rect.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        store.setHovering(inside)
    }
}

@MainActor
private final class DropTargetView: NSView {
    private let store: NotchStore

    init(frame: NSRect, store: NotchStore) {
        self.store = store
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
        store.send(.dragChanged(true))
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        store.send(.dragChanged(false))
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        store.send(.dragChanged(false))
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        store.send(.dragChanged(false))
        guard !urls.isEmpty else { return false }
        store.send(.stageFiles(urls))
        return true
    }
}
