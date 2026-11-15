import AppKit
import LocalAuthentication
import SwiftUI

@MainActor
public final class LockScreenWindowController {
    private let store: NotchStore
    private let faceAuth: FaceAuthService
    private let onMediaCommand: @MainActor (MediaCommand) -> Void

    private var lockWindows: [NSWindow] = []
    private var systemOverlayPanel: LockScreenPanel?
    private var systemOverlayMouseMonitor: Any?
    private let skyLightBridge = SkyLightBridge()
    private var systemLockMonitor: SystemLockStateMonitor?
    public private(set) var isLocked = false
    private var biometricContext: LAContext?
    private var keyMonitor: Any?
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
        self.autoLockOnSleepWake = UserDefaults.standard.bool(forKey: Self.autoLockDefaultsKey)
        installWorkspaceObservers()
        installSystemLockObserver()
    }

    isolated deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let systemOverlayMouseMonitor { NSEvent.removeMonitor(systemOverlayMouseMonitor) }
        let nc = NSWorkspace.shared.notificationCenter
        if let sleepObserver { nc.removeObserver(sleepObserver) }
        if let screenSleepObserver { nc.removeObserver(screenSleepObserver) }
        if let wakeObserver { nc.removeObserver(wakeObserver) }
    }

    private func installSystemLockObserver() {
        systemLockMonitor = SystemLockStateMonitor(spaceProvider: skyLightBridge) { [weak self] locked in
            guard let self else { return }
            if locked {
                self.showSystemLockOverlay()
            } else {
                self.hideSystemLockOverlay()
            }
        }
    }

    public func showSystemLockOverlay() {
        guard systemOverlayPanel == nil else { return }
        // Close any preview lock windows if open and reset faceAuth state for a fresh lock session
        if isLocked { unlock() }
        faceAuth.stop()

        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen = primary else { return }

        let panel = LockScreenPanel(contentRect: screen.frame, screen: screen)
        let rootView = LockScreenView(
            store: store,
            faceAuth: faceAuth,
            onMediaCommand: onMediaCommand,
            onAuthenticateWithSystem: {},
            onRetryFaceScan: { [weak self] in
                self?.beginSystemOverlayFaceVerification()
            },
            onEmergencyClose: { [weak self] in
                self?.hideSystemLockOverlay()
            },
            isSystemOverlay: true,
            onPresentationModeChange: { [weak panel] newMode in
                panel?.presentationMode = newMode
            }
        )
        .frame(width: screen.frame.width, height: screen.frame.height)

        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = []
        panel.contentViewController = hosting
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()

        systemLockMonitor?.attachWindow(windowNumber: panel.windowNumber)
        systemOverlayPanel = panel

        systemOverlayMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged]
        ) { [weak panel] _ in
            let mouse = NSEvent.mouseLocation
            Task { @MainActor [weak panel] in
                panel?.updateHitTesting(globalMouseLocation: mouse)
            }
        }
    }

    public func hideSystemLockOverlay() {
        if let systemOverlayMouseMonitor {
            NSEvent.removeMonitor(systemOverlayMouseMonitor)
            self.systemOverlayMouseMonitor = nil
        }
        faceAuth.stop()
        systemOverlayPanel?.orderOut(nil)
        systemOverlayPanel?.close()
        systemOverlayPanel = nil
    }

    private func beginSystemOverlayFaceVerification() {
        guard faceAuth.hasEnrolledFace else { return }
        systemOverlayPanel?.isScanningFace = true
        faceAuth.startVerification { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .milliseconds(450))
                if let password = SystemUnlockKeychain.loadPassword(), !password.isEmpty {
                    SystemUnlockKeychain.typePasswordAndSubmit(password)
                }
                try? await Task.sleep(for: .milliseconds(500))
                self.systemOverlayPanel?.isScanningFace = false
            }
        }
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
            unlock()
        } else {
            lock()
        }
    }

    public func lock() {
        guard !isLocked else { return }
        isLocked = true
        faceAuth.refreshPermissionStatus()

        // Keep Cmd+Tab and Force Quit available so the user can never be trapped
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        installEscapeKeyMonitor()

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
                    },
                    onEmergencyClose: { [weak self] in
                        self?.unlock()
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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
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

    private func installEscapeKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key always exits Lock Screen safely
                Task { @MainActor [weak self] in
                    self?.unlock()
                }
                return nil
            }
            return event
        }
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

public enum SystemUnlockKeychain {
    private static let service = "com.pawalit.MyNotchApp.autoUnlock"
    private static let account = "macOSLoginPassword"

    @discardableResult
    public static func savePassword(_ password: String) -> Bool {
        deletePassword()
        guard let data = password.data(using: .utf8), !data.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public static func loadPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func deletePassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public static func typePasswordAndSubmit(_ password: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        for utf16Unit in password.utf16 {
            var char = utf16Unit
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
                up.post(tap: .cghidEventTap)
            }
            usleep(6000)
        }
        usleep(30000)
        // Return key (36)
        if let retDown = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true) {
            retDown.post(tap: .cghidEventTap)
        }
        if let retUp = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false) {
            retUp.post(tap: .cghidEventTap)
        }
    }
}

