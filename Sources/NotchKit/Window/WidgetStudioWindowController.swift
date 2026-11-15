import AppKit
import SwiftUI

@MainActor
public final class WidgetStudioWindowController {
    private let config: NotchWidgetConfig
    private let onPreviewWidget: @MainActor (WidgetID) -> Void
    private var window: NSWindow?

    public init(
        config: NotchWidgetConfig,
        onPreviewWidget: @escaping @MainActor (WidgetID) -> Void
    ) {
        self.config = config
        self.onPreviewWidget = onPreviewWidget
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = WidgetStudioView(
            config: config,
            onPreviewWidget: onPreviewWidget
        )
        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Notch Widget Studio"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 780, height: 600))
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}

