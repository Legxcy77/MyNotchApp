import AppKit

/// Borderless, transparent, non-activating panel that floats above the notch on every Space.
final class NotchPanel: NSPanel {
    var allowsKeyWindow = false

    init(size: CGSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // SwiftUI draws its own shadow that follows the island shape
        isMovable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true // the controller enables it only over the island
        // Above the menu bar / notch (25), but below the system drag-image window (~500)
        // so dragged files remain visible on top of the island.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { allowsKeyWindow }
    override var canBecomeMain: Bool { false }
}

