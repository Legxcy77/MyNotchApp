import CoreGraphics
import Foundation
import Testing
@testable import NotchKit

@Suite("SkyLightBridgeTests")
struct SkyLightBridgeTests {
    @Test("SkyLightBridge loads on macOS without crashing")
    @MainActor
    func bridgeLoadsSafely() {
        let bridge = SkyLightBridge()
        // On macOS, SkyLight.framework is present; even if absent, init must not crash.
        #expect(bridge.isLoaded == true)
    }

    @Test("SystemLockStateMonitor handles lock and unlock events via SkyLightSpaceProviding")
    @MainActor
    func lockStateMonitorManagesSpaceLifecycle() async {
        let mockSpace = MockSkyLightSpaceProvider(isLoaded: true, nextSpaceID: 42)
        var events: [Bool] = []

        let monitor = SystemLockStateMonitor(
            spaceProvider: mockSpace,
            installDistributedObservers: false
        ) { locked in
            events.append(locked)
        }

        monitor.handleNotification(name: SystemLockStateMonitor.screenIsLockedNotification)
        #expect(events == [true])
        #expect(monitor.isSystemLocked == true)
        #expect(mockSpace.createdLevels == [400])
        #expect(mockSpace.shownSpaces == [42])

        monitor.attachWindow(windowNumber: 9001)
        #expect(mockSpace.movedWindows.count == 1)
        #expect(mockSpace.movedWindows.first?.windowNumber == 9001)
        #expect(mockSpace.movedWindows.first?.spaceID == 42)

        monitor.handleNotification(name: SystemLockStateMonitor.screenIsUnlockedNotification)
        #expect(events == [true, false])
        #expect(monitor.isSystemLocked == false)
        #expect(mockSpace.hiddenSpaces == [42])
        #expect(mockSpace.destroyedSpaces == [42])
        #expect(monitor.activeSpaceID == nil)
    }

    @Test("SystemLockStateMonitor falls back gracefully when SkyLight is unavailable")
    @MainActor
    func fallbackWhenSkyLightUnavailable() {
        let mockSpace = MockSkyLightSpaceProvider(isLoaded: false, nextSpaceID: 99)
        var events: [Bool] = []

        let monitor = SystemLockStateMonitor(
            spaceProvider: mockSpace,
            installDistributedObservers: false
        ) { locked in
            events.append(locked)
        }

        monitor.handleNotification(name: SystemLockStateMonitor.screenIsLockedNotification)
        #expect(events == [true])
        #expect(monitor.activeSpaceID == nil)
        #expect(mockSpace.createdLevels.isEmpty)
    }

    @Test("LockScreenOverlayLayout hit-rects never cover top clock or bottom Touch ID / password zone")
    func hitRectsAvoidTopClockAndBottomPasswordZones() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let topClockZone = CGRect(x: 0, y: screenFrame.height * 0.76, width: screenFrame.width, height: screenFrame.height * 0.24)
        let bottomPasswordZone = CGRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height * 0.22)

        for mode in [LockPlayerPresentation.compact, .albumFocus, .lyricsSplit] {
            let rect = LockScreenOverlayLayout.interactiveRect(in: screenFrame, mode: mode)
            #expect(!rect.isEmpty)
            #expect(!rect.intersects(topClockZone), "Mode \(mode) must not overlap top clock")
            #expect(!rect.intersects(bottomPasswordZone), "Mode \(mode) must not overlap bottom Touch ID / password zone")

            // Center of card is interactive; corners outside card click through.
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let bottomLeftCorner = CGPoint(x: 40, y: 40)
            #expect(LockScreenOverlayLayout.shouldCaptureMouse(at: center, in: screenFrame, mode: mode) == true)
            #expect(LockScreenOverlayLayout.shouldCaptureMouse(at: bottomLeftCorner, in: screenFrame, mode: mode) == false)
        }
    }

    @Test("LockScreenOverlayLayout captures top-center Notch zone for Face ID without blocking sides")
    func notchHitRectCapturesTopCenterOnly() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let idleNotch = LockScreenOverlayLayout.notchHitRect(in: screenFrame, isScanning: false)
        let scanningNotch = LockScreenOverlayLayout.notchHitRect(in: screenFrame, isScanning: true)

        #expect(scanningNotch.width > idleNotch.width)
        #expect(LockScreenOverlayLayout.isMouseOverNotch(CGPoint(x: 756, y: 970), in: screenFrame, isScanning: false) == true)
        #expect(LockScreenOverlayLayout.isMouseOverNotch(CGPoint(x: 200, y: 970), in: screenFrame, isScanning: false) == false)
        #expect(LockScreenOverlayLayout.shouldCaptureMouse(
            at: CGPoint(x: 756, y: 970),
            in: screenFrame,
            mode: .compact,
            isScanningFace: false
        ) == true)
    }
}

@MainActor
private final class MockSkyLightSpaceProvider: SkyLightSpaceProviding {
    let isLoaded: Bool
    private let nextSpaceID: UInt64
    var createdLevels: [Int32] = []
    var shownSpaces: [UInt64] = []
    var hiddenSpaces: [UInt64] = []
    var destroyedSpaces: [UInt64] = []
    var movedWindows: [(windowNumber: Int, spaceID: UInt64)] = []

    init(isLoaded: Bool, nextSpaceID: UInt64) {
        self.isLoaded = isLoaded
        self.nextSpaceID = nextSpaceID
    }

    func createLockSpace(level: Int32) -> UInt64? {
        guard isLoaded else { return nil }
        createdLevels.append(level)
        return nextSpaceID
    }

    func destroySpace(_ spaceID: UInt64) {
        destroyedSpaces.append(spaceID)
    }

    func moveWindow(_ windowNumber: Int, toSpace spaceID: UInt64) {
        movedWindows.append((windowNumber, spaceID))
    }

    func showSpace(_ spaceID: UInt64) {
        shownSpaces.append(spaceID)
    }

    func hideSpace(_ spaceID: UInt64) {
        hiddenSpaces.append(spaceID)
    }
}
