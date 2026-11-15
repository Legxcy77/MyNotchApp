import CoreGraphics
import Darwin
import Foundation

@MainActor
public protocol SkyLightSpaceProviding: AnyObject {
    var isLoaded: Bool { get }
    func createLockSpace(level: Int32) -> UInt64?
    func destroySpace(_ spaceID: UInt64)
    func moveWindow(_ windowNumber: Int, toSpace spaceID: UInt64)
    func showSpace(_ spaceID: UInt64)
    func hideSpace(_ spaceID: UInt64)
}

/// Dynamic `dlopen`/`dlsym` bridge to `SkyLight.framework` for floating a non-blocking
/// overlay space above `loginwindow` when macOS is locked.
/// Falls back cleanly (`isLoaded == false`) if any symbol is missing on future OS updates.
@MainActor
public final class SkyLightBridge: SkyLightSpaceProviding {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceDestroyFn = @convention(c) (Int32, UInt64) -> Int32
    private typealias SpaceSetAbsoluteLevelFn = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias HideSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindowsFn = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32
    private typealias CopyCurrentSessionFn = @convention(c) () -> Unmanaged<CFDictionary>?

    private static let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

    private let mainConnectionID: MainConnectionFn?
    private let spaceCreate: SpaceCreateFn?
    private let spaceDestroy: SpaceDestroyFn?
    private let spaceSetAbsoluteLevel: SpaceSetAbsoluteLevelFn?
    private let showSpaces: ShowSpacesFn?
    private let hideSpaces: HideSpacesFn?
    private let spaceAddWindowsAndRemoveFromSpaces: SpaceAddWindowsFn?
    private let copyCurrentSessionDictionary: CopyCurrentSessionFn?

    public let isLoaded: Bool

    public init() {
        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY) else {
            self.mainConnectionID = nil
            self.spaceCreate = nil
            self.spaceDestroy = nil
            self.spaceSetAbsoluteLevel = nil
            self.showSpaces = nil
            self.hideSpaces = nil
            self.spaceAddWindowsAndRemoveFromSpaces = nil
            self.copyCurrentSessionDictionary = nil
            self.isLoaded = false
            return
        }

        let conn = dlsym(handle, "SLSMainConnectionID").map { unsafeBitCast($0, to: MainConnectionFn.self) }
        let create = dlsym(handle, "SLSSpaceCreate").map { unsafeBitCast($0, to: SpaceCreateFn.self) }
        let destroy = dlsym(handle, "SLSSpaceDestroy").map { unsafeBitCast($0, to: SpaceDestroyFn.self) }
        let setLevel = dlsym(handle, "SLSSpaceSetAbsoluteLevel").map { unsafeBitCast($0, to: SpaceSetAbsoluteLevelFn.self) }
        let show = dlsym(handle, "SLSShowSpaces").map { unsafeBitCast($0, to: ShowSpacesFn.self) }
        let hide = dlsym(handle, "SLSHideSpaces").map { unsafeBitCast($0, to: HideSpacesFn.self) }
        let addWin = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces").map {
            unsafeBitCast($0, to: SpaceAddWindowsFn.self)
        }
        let session = dlsym(handle, "CGSCopyCurrentSessionDictionary").map {
            unsafeBitCast($0, to: CopyCurrentSessionFn.self)
        }

        self.mainConnectionID = conn
        self.spaceCreate = create
        self.spaceDestroy = destroy
        self.spaceSetAbsoluteLevel = setLevel
        self.showSpaces = show
        self.hideSpaces = hide
        self.spaceAddWindowsAndRemoveFromSpaces = addWin
        self.copyCurrentSessionDictionary = session

        self.isLoaded = (
            conn != nil &&
            create != nil &&
            destroy != nil &&
            setLevel != nil &&
            show != nil &&
            hide != nil &&
            addWin != nil
        )
    }

    public func isSessionLockedViaCGS() -> Bool {
        guard let fn = copyCurrentSessionDictionary,
              let dict = fn()?.takeRetainedValue() as? [String: Any] else {
            return false
        }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    public func createLockSpace(level: Int32 = 400) -> UInt64? {
        guard isLoaded,
              let connFn = mainConnectionID,
              let createFn = spaceCreate,
              let levelFn = spaceSetAbsoluteLevel else {
            return nil
        }
        let cid = connFn()
        // type 1 = system/managed overlay space
        let spaceID = createFn(cid, 1, nil)
        guard spaceID != 0 else { return nil }
        _ = levelFn(cid, spaceID, level)
        return spaceID
    }

    public func destroySpace(_ spaceID: UInt64) {
        guard isLoaded, let connFn = mainConnectionID, let destroyFn = spaceDestroy else { return }
        _ = destroyFn(connFn(), spaceID)
    }

    public func moveWindow(_ windowNumber: Int, toSpace spaceID: UInt64) {
        guard isLoaded,
              let connFn = mainConnectionID,
              let addFn = spaceAddWindowsAndRemoveFromSpaces else {
            return
        }
        let windows = [NSNumber(value: windowNumber)] as CFArray
        _ = addFn(connFn(), spaceID, windows, 7)
    }

    public func showSpace(_ spaceID: UInt64) {
        guard isLoaded, let connFn = mainConnectionID, let showFn = showSpaces else { return }
        let spaces = [NSNumber(value: spaceID)] as CFArray
        _ = showFn(connFn(), spaces)
    }

    public func hideSpace(_ spaceID: UInt64) {
        guard isLoaded, let connFn = mainConnectionID, let hideFn = hideSpaces else { return }
        let spaces = [NSNumber(value: spaceID)] as CFArray
        _ = hideFn(connFn(), spaces)
    }
}

/// Observes `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` and manages the
/// SkyLight overlay space lifecycle.
@MainActor
public final class SystemLockStateMonitor {
    public static let screenIsLockedNotification = "com.apple.screenIsLocked"
    public static let screenIsUnlockedNotification = "com.apple.screenIsUnlocked"

    private let spaceProvider: any SkyLightSpaceProviding
    private let onLockStateChanged: @MainActor (Bool) -> Void
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?

    public private(set) var isSystemLocked = false
    public private(set) var activeSpaceID: UInt64?

    public init(
        spaceProvider: any SkyLightSpaceProviding,
        installDistributedObservers: Bool = true,
        onLockStateChanged: @escaping @MainActor (Bool) -> Void
    ) {
        self.spaceProvider = spaceProvider
        self.onLockStateChanged = onLockStateChanged

        if installDistributedObservers {
            let dnc = DistributedNotificationCenter.default()
            lockObserver = dnc.addObserver(
                forName: Notification.Name(Self.screenIsLockedNotification),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleNotification(name: Self.screenIsLockedNotification)
                }
            }
            unlockObserver = dnc.addObserver(
                forName: Notification.Name(Self.screenIsUnlockedNotification),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleNotification(name: Self.screenIsUnlockedNotification)
                }
            }
        }
    }

    isolated deinit {
        let dnc = DistributedNotificationCenter.default()
        if let lockObserver { dnc.removeObserver(lockObserver) }
        if let unlockObserver { dnc.removeObserver(unlockObserver) }
        if let activeSpaceID {
            spaceProvider.hideSpace(activeSpaceID)
            spaceProvider.destroySpace(activeSpaceID)
        }
    }

    public func handleNotification(name: String) {
        switch name {
        case Self.screenIsLockedNotification:
            guard !isSystemLocked else { return }
            isSystemLocked = true
            if spaceProvider.isLoaded, let spaceID = spaceProvider.createLockSpace(level: 400) {
                activeSpaceID = spaceID
                spaceProvider.showSpace(spaceID)
            }
            onLockStateChanged(true)

        case Self.screenIsUnlockedNotification:
            guard isSystemLocked else { return }
            isSystemLocked = false
            if let spaceID = activeSpaceID {
                spaceProvider.hideSpace(spaceID)
                spaceProvider.destroySpace(spaceID)
                activeSpaceID = nil
            }
            onLockStateChanged(false)

        default:
            break
        }
    }

    public func attachWindow(windowNumber: Int) {
        guard let spaceID = activeSpaceID else { return }
        spaceProvider.moveWindow(windowNumber, toSpace: spaceID)
    }
}

/// Pure geometry calculator for the floating card on the real macOS Lock Screen.
/// Guarantees the interactive hit-rect stays in the middle band and never overlaps
/// the top system clock (`> 76%` height) or bottom Touch ID / password field (`< 22%` height).
public enum LockScreenOverlayLayout {
    public static func interactiveRect(in screenFrame: CGRect, mode: LockPlayerPresentation) -> CGRect {
        let size: CGSize
        switch mode {
        case .compact:
            size = CGSize(width: 460, height: 155)
        case .albumFocus:
            size = CGSize(width: 400, height: 490)
        case .lyricsSplit:
            size = CGSize(width: 840, height: 440)
        }

        // Clamp height inside the safe middle band [0.23 * H, 0.75 * H]
        let minSafeY = screenFrame.minY + screenFrame.height * 0.23
        let maxSafeTop = screenFrame.minY + screenFrame.height * 0.75
        let safeHeight = max(80, maxSafeTop - minSafeY)
        let clampedHeight = min(size.height, safeHeight)
        let clampedWidth = min(size.width, max(280, screenFrame.width - 64))

        let originX = screenFrame.midX - clampedWidth / 2
        let originY = minSafeY + (safeHeight - clampedHeight) / 2
        return CGRect(x: originX, y: originY, width: clampedWidth, height: clampedHeight)
    }

    public static func notchHitRect(in screenFrame: CGRect, isScanning: Bool) -> CGRect {
        let width: CGFloat = isScanning ? 440 : 260
        let height: CGFloat = 52
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    public static func isMouseOverNotch(
        _ point: CGPoint,
        in screenFrame: CGRect,
        isScanning: Bool
    ) -> Bool {
        notchHitRect(in: screenFrame, isScanning: isScanning).contains(point)
    }

    public static func shouldCaptureMouse(
        at point: CGPoint,
        in screenFrame: CGRect,
        mode: LockPlayerPresentation,
        isScanningFace: Bool = false
    ) -> Bool {
        interactiveRect(in: screenFrame, mode: mode).contains(point)
            || notchHitRect(in: screenFrame, isScanning: isScanningFace).contains(point)
    }
}

