import AppKit
import LocalAuthentication
import SwiftUI

@MainActor
public final class LockScreenWindowController {
    private let store: NotchStore
    private let faceAuth: FaceAuthService
    private let onMediaCommand: @MainActor (MediaCommand) -> Void

    private var lockWindows: [NSWindow] = []
    public private(set) var isLocked = false
    private var biometricContext: LAContext?
    public var autoLockOnSleepWake: Bool {
        didSet {
            UserDefaults.standard.set(autoLockOnSleepWake, forKey: Self.autoLockDefaultsKey)
        }
    }
    private static let autoLockDefaultsKey = "mynotch.autoLockOnSleepWake"
    private var sleepObserver: NSObjectProtocol?
    private var screenSleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    public init(
        store: NotchStore,
        faceAuth: FaceAuthService,
        onMediaCommand: @escaping @MainActor (MediaCommand) -> Void
    ) {
        self.store = store
        self.faceAuth = faceAuth
        self.onMediaCommand = onMediaCommand
        if UserDefaults.standard.object(forKey: Self.autoLockDefaultsKey) == nil {
            self.autoLockOnSleepWake = true
        } else {
            self.autoLockOnSleepWake = UserDefaults.standard.bool(forKey: Self.autoLockDefaultsKey)
        }
        installWorkspaceObservers()
    }

    isolated deinit {
        let nc = NSWorkspace.shared.notificationCenter
        if let sleepObserver { nc.removeObserver(sleepObserver) }
        if let screenSleepObserver { nc.removeObserver(screenSleepObserver) }
        if let wakeObserver { nc.removeObserver(wakeObserver) }
    }

    private func installWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        sleepObserver = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.autoLockOnSleepWake else { return }
                self.lock()
            }
        }
        screenSleepObserver = nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.autoLockOnSleepWake else { return }
                self.lock()
            }
        }
        wakeObserver = nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.autoLockOnSleepWake else { return }
                if !self.isLocked {
                    self.lock()
                }
            }
        }
    }

    public func toggleLock() {
        if isLocked {
            authenticateWithSystem()
        } else {
            lock()
        }
    }

    public func lock() {
        guard !isLocked else { return }
        isLocked = true
        faceAuth.refreshPermissionStatus()

        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]

        let screens = NSScreen.screens
        let primary = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first
        var created: [NSWindow] = []

        for screen in screens {
            let win = LockScreenWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.isReleasedWhenClosed = false
            win.backgroundColor = .black

            if screen == primary {
                let rootView = LockScreenView(
                    store: store,
                    faceAuth: faceAuth,
                    onMediaCommand: onMediaCommand,
                    onAuthenticateWithSystem: { [weak self] in
                        self?.authenticateWithSystem()
                    },
                    onRetryFaceScan: { [weak self] in
                        self?.beginFaceVerification()
                    }
                )
                .frame(width: screen.frame.width, height: screen.frame.height)
                let hosting = NSHostingController(rootView: rootView)
                hosting.sizingOptions = []
                win.contentViewController = hosting
                win.setFrame(screen.frame, display: true)
                win.makeKeyAndOrderFront(nil)
            } else {
                let cover = NSView(frame: screen.frame)
                cover.wantsLayer = true
                cover.layer?.backgroundColor = NSColor.black.cgColor
                win.contentView = cover
                win.setFrame(screen.frame, display: true)
                win.orderFrontRegardless()
            }
            created.append(win)
        }

        lockWindows = created
        NSApp.activate(ignoringOtherApps: true)
        beginTouchIDListener()
    }

    public func unlock() {
        guard isLocked else { return }
        isLocked = false
        biometricContext?.invalidate()
        biometricContext = nil
        faceAuth.stop()
        NSApp.presentationOptions = []

        for win in lockWindows {
            win.orderOut(nil)
            win.close()
        }
        lockWindows.removeAll()

        store.post(Toast(
            title: "Unlocked",
            symbol: "lock.open.fill",
            tint: .success,
            duration: .seconds(2)
        ))
    }

    private func beginFaceVerification() {
        guard isLocked, faceAuth.hasEnrolledFace else { return }
        biometricContext?.invalidate()
        biometricContext = nil
        faceAuth.startVerification { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                self?.unlock()
            }
        }
    }

    private func beginTouchIDListener() {
        let context = LAContext()
        context.localizedFallbackTitle = "ใช้รหัสผ่าน"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }
        biometricContext = context
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "สแกนนิ้วเพื่อปลดล็อก MyNotchApp"
        ) { [weak self] success, evalError in
            Task { @MainActor [weak self] in
                guard let self, self.isLocked else { return }
                self.biometricContext = nil
                if success {
                    self.unlock()
                } else if let laError = evalError as? LAError, laError.code == .userFallback {
                    self.authenticateWithSystem()
                }
            }
        }
    }

    private func authenticateWithSystem() {
        biometricContext?.invalidate()
        biometricContext = nil
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Fallback: if system has no auth configured, unlock cleanly
            unlock()
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "ปลดล็อกหน้าจอ MyNotchApp"
        ) { [weak self] success, _ in
            Task { @MainActor [weak self] in
                if success {
                    self?.unlock()
                }
            }
        }
    }
}

private final class LockScreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

