import CoreAudio
import Foundation

public struct BluetoothAudioBatteryInfo: Equatable, Sendable {
    public let deviceName: String
    public let leftPercent: Int?
    public let rightPercent: Int?
    public let casePercent: Int?
    public let singlePercent: Int?

    public var isAirPods: Bool {
        deviceName.localizedCaseInsensitiveContains("airpods")
    }

    public var symbolName: String {
        let lower = deviceName.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods.gen3" }
        return "headphones"
    }

    public var summaryText: String {
        var parts: [String] = []
        if let leftPercent { parts.append("L \(leftPercent)%") }
        if let rightPercent { parts.append("R \(rightPercent)%") }
        if let casePercent { parts.append("Case \(casePercent)%") }
        if parts.isEmpty, let singlePercent {
            return "Battery \(singlePercent)%"
        }
        return parts.joined(separator: " · ")
    }
}

public enum AirPodsBatteryParser {
    public static func parse(_ jsonData: Data) -> [BluetoothAudioBatteryInfo] {
        guard let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let entries = root["SPBluetoothDataType"] as? [[String: Any]] else {
            return []
        }

        var results: [BluetoothAudioBatteryInfo] = []
        for entry in entries {
            guard let connected = entry["device_connected"] as? [[String: Any]] else { continue }
            for deviceDict in connected {
                for (name, rawProps) in deviceDict {
                    guard let props = rawProps as? [String: Any] else { continue }
                    let left = parsePercent(props["device_batteryLevelLeft"])
                    let right = parsePercent(props["device_batteryLevelRight"])
                    let caseLevel = parsePercent(props["device_batteryLevelCase"])
                    let main = parsePercent(props["device_batteryLevelMain"])
                    guard left != nil || right != nil || caseLevel != nil || main != nil else { continue }
                    results.append(BluetoothAudioBatteryInfo(
                        deviceName: name,
                        leftPercent: left,
                        rightPercent: right,
                        casePercent: caseLevel,
                        singlePercent: main
                    ))
                }
            }
        }
        return results
    }

    private static func parsePercent(_ value: Any?) -> Int? {
        if let intVal = value as? Int {
            return min(100, max(0, intVal))
        }
        if let strVal = value as? String {
            let digits = strVal.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let parsed = Int(digits) {
                return min(100, max(0, parsed))
            }
        }
        return nil
    }
}

/// Event-driven Bluetooth / AirPods battery popup monitor.
/// Listens to CoreAudio `kAudioHardwarePropertyDefaultOutputDevice` changes (0% idle CPU)
/// and queries `system_profiler SPBluetoothDataType -json` only when the output device changes.
@MainActor
public final class AirPodsBatteryMonitor {
    private let onBatteryToast: @MainActor (Toast) -> Void
    private var lastAnnouncedDevices: Set<String> = []
    private var listenerAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var devicesListenerAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var delayedRefreshTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.airpods.listener")

    public init(onBatteryToast: @escaping @MainActor (Toast) -> Void) {
        self.onBatteryToast = onBatteryToast
    }

    isolated deinit {
        delayedRefreshTask?.cancel()
        if let block = listenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &listenerAddress,
                queue,
                block
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesListenerAddress,
                queue,
                block
            )
            listenerBlock = nil
        }
    }

    public func start() {
        guard listenerBlock == nil else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &listenerAddress,
            queue,
            block
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesListenerAddress,
            queue,
            block
        )
        refreshBluetoothDevices()
    }

    private func scheduleRefresh() {
        refreshBluetoothDevices()
        delayedRefreshTask?.cancel()
        delayedRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.refreshBluetoothDevices()
        }
    }

    public func refreshBluetoothDevices() {
        Task { [weak self] in
            let data = await Self.runSystemProfiler()
            guard let data else { return }
            let devices = AirPodsBatteryParser.parse(data)
            await MainActor.run { [weak self] in
                self?.handleParsedDevices(devices)
            }
        }
    }

    private func handleParsedDevices(_ devices: [BluetoothAudioBatteryInfo]) {
        let currentNames = Set(devices.map(\.deviceName))
        let newlyConnected = devices.filter { !lastAnnouncedDevices.contains($0.deviceName) }
        lastAnnouncedDevices = currentNames

        for info in newlyConnected {
            onBatteryToast(Toast(
                key: "bluetooth:battery:\(info.deviceName)",
                title: info.deviceName,
                subtitle: info.summaryText,
                symbol: info.symbolName,
                tint: .info,
                priority: .high,
                duration: .seconds(4)
            ))
        }
    }

    private static func runSystemProfiler() async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                proc.arguments = ["SPBluetoothDataType", "-json"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus == 0 ? data : nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

