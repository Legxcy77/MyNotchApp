import Foundation

public struct SystemPulseSample: Equatable, Sendable {
    public let cpuPercent: Double
    public let ramUsedGB: Double
    public let ramTotalGB: Double
    public let timestamp: Date

    public init(cpuPercent: Double, ramUsedGB: Double, ramTotalGB: Double, timestamp: Date = .now) {
        self.cpuPercent = min(100, max(0, cpuPercent))
        self.ramUsedGB = max(0, ramUsedGB)
        self.ramTotalGB = max(0, ramTotalGB)
        self.timestamp = timestamp
    }
}

public struct HotProcess: Equatable, Sendable {
    public let pid: Int32
    public let cpuPercent: Double
    public let name: String

    public init(pid: Int32, cpuPercent: Double, name: String) {
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.name = name
    }
}

public enum SystemPulseParser {
    public static func parseTopProcesses(_ output: String) -> [HotProcess] {
        var result: [HotProcess] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("PID") else { continue }
            let parts = trimmed.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")) else { continue }
            result.append(HotProcess(pid: pid, cpuPercent: cpu, name: String(parts[2])))
        }
        return result
    }
}

public struct SystemPulseTracker: Sendable {
    private var hotSince: [Int32: Date] = [:]
    private var alerted: Set<Int32> = []
    private let threshold: Double
    private let duration: TimeInterval

    public init(threshold: Double = 90.0, duration: TimeInterval = 30.0) {
        self.threshold = threshold
        self.duration = duration
    }

    public mutating func ingest(_ processes: [HotProcess], at now: Date = .now) -> HotProcess? {
        let hot = processes.filter { $0.cpuPercent >= threshold }
        let hotPIDs = Set(hot.map(\.pid))
        hotSince = hotSince.filter { hotPIDs.contains($0.key) }
        alerted = alerted.intersection(hotPIDs)

        for proc in hot {
            if let first = hotSince[proc.pid] {
                if !alerted.contains(proc.pid), now.timeIntervalSince(first) >= duration {
                    alerted.insert(proc.pid)
                    return proc
                }
            } else {
                hotSince[proc.pid] = now
            }
        }
        return nil
    }
}
