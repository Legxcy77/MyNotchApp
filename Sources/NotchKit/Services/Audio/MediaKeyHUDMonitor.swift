import AppKit
import CoreGraphics
import Darwin
import Foundation

public enum MediaHUDKey: Equatable, Sendable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
    case keyboardBrightnessUp
    case keyboardBrightnessDown
}

public enum MediaKeyEventDecoder {
    // NX_KEYTYPE constants from IOKit/hidsystem/ev_keymap.h
    private static let nxSoundUp = 0
    private static let nxSoundDown = 1
    private static let nxBrightnessUp = 2
    private static let nxBrightnessDown = 3
    private static let nxMute = 7
    private static let nxIlluminationUp = 21
    private static let nxIlluminationDown = 22

    public static func decode(subtype: Int16, data1: Int) -> MediaHUDKey? {
        guard subtype == 8 else { return nil }
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A
        guard isKeyDown else { return nil }

        switch keyCode {
        case nxSoundUp: return .volumeUp
        case nxSoundDown: return .volumeDown
        case nxMute: return .mute
        case nxBrightnessUp: return .brightnessUp
        case nxBrightnessDown: return .brightnessDown
        case nxIlluminationUp: return .keyboardBrightnessUp
        case nxIlluminationDown: return .keyboardBrightnessDown
        default: return nil
        }
    }

    public static func volumeSymbol(level: Double, isMuted: Bool) -> String {
        if isMuted { return "speaker.slash.fill" }
        if level <= 0.01 { return "speaker.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Dynamic `dlopen`/`dlsym` reader/writer for DisplayServices brightness with safe nil fallback.
@MainActor
public final class DisplayBrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightnessFn: GetBrightnessFn?
    private let setBrightnessFn: SetBrightnessFn?

    public init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_LAZY) {
            self.getBrightnessFn = dlsym(handle, "DisplayServicesGetBrightness").map {
                unsafeBitCast($0, to: GetBrightnessFn.self)
            }
            self.setBrightnessFn = dlsym(handle, "DisplayServicesSetBrightness").map {
                unsafeBitCast($0, to: SetBrightnessFn.self)
            }
        } else {
            self.getBrightnessFn = nil
            self.setBrightnessFn = nil
        }
    }

    public func currentMainDisplayBrightness() -> Double? {
        guard let fn = getBrightnessFn else { return nil }
        var brightness: Float = 0
        let status = fn(CGMainDisplayID(), &brightness)
        guard status == 0 else { return nil }
        return Double(min(1, max(0, brightness)))
    }

    @discardableResult
    public func setMainDisplayBrightness(_ value: Double) -> Bool {
        guard let fn = setBrightnessFn else { return false }
        let clamped = Float(min(1, max(0, value)))
        return fn(CGMainDisplayID(), clamped) == 0
    }
}

/// Listens for Volume, Mute, Display Brightness, and Keyboard Backlight keys
/// and posts keyed progress HUD toasts into the Notch.
@MainActor
public final class MediaKeyHUDMonitor {
    private let onHUDToast: @MainActor (Toast) -> Void
    private let brightnessReader = DisplayBrightnessReader()
    private var monitors: [Any] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastKeyboardLevel: Double = 0.5

    public init(onHUDToast: @escaping @MainActor (Toast) -> Void) {
        self.onHUDToast = onHUDToast
    }

    isolated deinit {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    public func start() {
        if installActiveEventTap() {
            return
        }
        // Fallback: passive global/local monitors if Accessibility is not yet granted
        guard monitors.isEmpty else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event: event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .systemDefined, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event: event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func installActiveEventTap() -> Bool {
        guard eventTap == nil else { return true }
        // NX_SYSDEFINED = 14
        let mask = CGEventMask(1 << 14)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                let monitor = Unmanaged<MediaKeyHUDMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                MainActor.assumeIsolated {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passUnretained(cgEvent)
            }

            guard let nsEvent = NSEvent(cgEvent: cgEvent),
                  nsEvent.type == .systemDefined,
                  let key = MediaKeyEventDecoder.decode(subtype: nsEvent.subtype.rawValue, data1: nsEvent.data1) else {
                return Unmanaged.passUnretained(cgEvent)
            }

            let monitor = Unmanaged<MediaKeyHUDMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            let suppressed = MainActor.assumeIsolated {
                monitor.handleActiveTapKey(key)
            }
            return suppressed ? nil : Unmanaged.passUnretained(cgEvent)
        }

        let tapLocations: [CGEventTapLocation] = [.cghidEventTap, .cgSessionEventTap]
        var createdTap: CFMachPort?
        for location in tapLocations {
            if let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: refcon
            ) {
                createdTap = tap
                break
            }
        }
        guard let tap = createdTap else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    /// Returns `true` if the event was handled & system OSD should be suppressed.
    private func handleActiveTapKey(_ key: MediaHUDKey) -> Bool {
        let step: Float = 1.0 / 16.0
        switch key {
        case .volumeUp:
            let snap = AudioDeviceService.currentSnapshot()
            let next = min(1.0, snap.volume + step)
            AudioDeviceService.setMuted(false)
            AudioDeviceService.setVolume(next)
            emitHUD(for: .volumeUp)
            return true
        case .volumeDown:
            let snap = AudioDeviceService.currentSnapshot()
            let next = max(0.0, snap.volume - step)
            AudioDeviceService.setVolume(next)
            if next <= 0.001 { AudioDeviceService.setMuted(true) }
            emitHUD(for: .volumeDown)
            return true
        case .mute:
            let snap = AudioDeviceService.currentSnapshot()
            AudioDeviceService.setMuted(!snap.isMuted)
            emitHUD(for: .mute)
            return true
        case .brightnessUp:
            if let cur = brightnessReader.currentMainDisplayBrightness(),
               brightnessReader.setMainDisplayBrightness(min(1.0, cur + 1.0 / 16.0)) {
                emitHUD(for: .brightnessUp)
                return true
            }
            handlePassiveKey(.brightnessUp)
            return false
        case .brightnessDown:
            if let cur = brightnessReader.currentMainDisplayBrightness(),
               brightnessReader.setMainDisplayBrightness(max(0.0, cur - 1.0 / 16.0)) {
                emitHUD(for: .brightnessDown)
                return true
            }
            handlePassiveKey(.brightnessDown)
            return false
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            emitHUD(for: key)
            return false
        }
    }

    private func handlePassiveKey(_ key: MediaHUDKey) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            self?.emitHUD(for: key)
        }
    }

    private func handle(event: NSEvent) {
        guard event.type == .systemDefined,
              let key = MediaKeyEventDecoder.decode(subtype: event.subtype.rawValue, data1: event.data1) else {
            return
        }

        // Slight delay (30ms) so macOS updates CoreAudio/DisplayServices before we read the new value
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            self?.emitHUD(for: key)
        }
    }

    private func emitHUD(for key: MediaHUDKey) {
        switch key {
        case .volumeUp, .volumeDown, .mute:
            let snap = AudioDeviceService.currentSnapshot()
            let level = Double(snap.volume)
            let symbol = MediaKeyEventDecoder.volumeSymbol(level: level, isMuted: snap.isMuted)
            onHUDToast(Toast(
                key: "hud:volume",
                title: snap.isMuted ? "Muted" : "Volume",
                symbol: symbol,
                tint: .neutral,
                priority: .high,
                duration: .seconds(1.5),
                progress: snap.isMuted ? 0 : level
            ))

        case .brightnessUp, .brightnessDown:
            guard let brightness = brightnessReader.currentMainDisplayBrightness() else { return }
            onHUDToast(Toast(
                key: "hud:brightness",
                title: "Display",
                symbol: brightness > 0.5 ? "sun.max.fill" : "sun.min.fill",
                tint: .neutral,
                priority: .high,
                duration: .seconds(1.5),
                progress: brightness
            ))

        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            let step = 1.0 / 16.0
            lastKeyboardLevel = min(1, max(0, lastKeyboardLevel + (key == .keyboardBrightnessUp ? step : -step)))
            onHUDToast(Toast(
                key: "hud:keyboard",
                title: "Keyboard",
                symbol: key == .keyboardBrightnessUp ? "light.max" : "light.min",
                tint: .neutral,
                priority: .high,
                duration: .seconds(1.5),
                progress: lastKeyboardLevel
            ))
        }
    }
}

