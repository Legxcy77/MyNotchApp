import Foundation
import IOKit.ps

public struct PowerSourceSnapshot: Equatable, Sendable {
    public let isACPower: Bool
    public let isCharging: Bool
    public let batteryPercent: Int
    public let watts: Int?

    public init(isACPower: Bool, isCharging: Bool, batteryPercent: Int, watts: Int?) {
        self.isACPower = isACPower
        self.isCharging = isCharging
        self.batteryPercent = batteryPercent
        self.watts = watts
    }
}

public enum PowerSourceParser {
    public static func parse(description: [String: Any], adapterWatts: Int?) -> PowerSourceSnapshot {
        let state = description[kIOPSPowerSourceStateKey] as? String ?? ""
        let isAC = state == kIOPSACPowerValue
        let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = max(1, description[kIOPSMaxCapacityKey] as? Int ?? 100)
        let pct = min(100, max(0, Int((Double(current) / Double(maxCap) * 100.0).rounded())))
        return PowerSourceSnapshot(
            isACPower: isAC,
            isCharging: isCharging,
            batteryPercent: pct,
            watts: isAC ? adapterWatts : nil
        )
    }
}

@MainActor
public final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var lastWasAC: Bool?
    private let onPluggedIn: @MainActor (PowerSourceSnapshot) -> Void

    public init(onPluggedIn: @escaping @MainActor (PowerSourceSnapshot) -> Void) {
        self.onPluggedIn = onPluggedIn
    }

    isolated deinit {
        stop()
    }

    public func start() {
        stop()
        lastWasAC = currentSnapshot()?.isACPower

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                monitor.handlePowerChange()
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    private func handlePowerChange() {
        guard let snap = currentSnapshot() else { return }
        let wasAC = lastWasAC ?? snap.isACPower
        lastWasAC = snap.isACPower
        if !wasAC && snap.isACPower {
            onPluggedIn(snap)
        }
    }

    public func currentSnapshot() -> PowerSourceSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let desc = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        let watts = adapter?[kIOPSPowerAdapterWattsKey] as? Int
        return PowerSourceParser.parse(description: desc, adapterWatts: watts)
    }
}

