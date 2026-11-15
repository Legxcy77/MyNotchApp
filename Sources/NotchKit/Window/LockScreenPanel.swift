import AppKit

/// Transparent floating panel used for the real macOS Lock Screen (`loginwindow`) overlay.
/// Areas outside the centered media/FaceID card click straight through to macOS Touch ID / password fields.
@MainActor
public final class LockScreenPanel: NSPanel {
    public var presentationMode: LockPlayerPresentation = .albumFocus
    public var isScanningFace: Bool = false
    private var isHoveringNotch: Bool = false

    public init(contentRect: CGRect, screen: NSScreen?) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        if let screen {
            setFrame(screen.frame, display: false)
        }
        isFloatingPanel = true
        canBecomeVisibleWithoutLogin = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        ignoresMouseEvents = true
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public func updateHitTesting(globalMouseLocation: CGPoint) {
        let overNotch = LockScreenOverlayLayout.isMouseOverNotch(
            globalMouseLocation,
            in: frame,
            isScanning: isScanningFace
        )
        if overNotch && !isHoveringNotch {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        isHoveringNotch = overNotch

        let shouldCapture = LockScreenOverlayLayout.shouldCaptureMouse(
            at: globalMouseLocation,
            in: frame,
            mode: presentationMode,
            isScanningFace: isScanningFace
        )
        let newIgnores = !shouldCapture
        if ignoresMouseEvents != newIgnores {
            ignoresMouseEvents = newIgnores
        }
    }
}

