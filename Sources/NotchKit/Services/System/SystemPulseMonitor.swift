import Darwin
import Foundation

@MainActor
public final class SystemPulseMonitor {
    private let onSample: @MainActor ([SystemPulseSample], HotProcess?) -> Void
    private var task: Task<Void, Never>?
    private var samples: [SystemPulseSample] = []
    private var tracker = SystemPulseTracker()
    private var prevCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    public init(onSample: @escaping @MainActor ([SystemPulseSample], HotProcess?) -> Void) {
        self.onSample = onSample
    }

    isolated deinit {
        task?.cancel()
    }

    public func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        let sample = readSystemSample()
        samples.append(sample)
        if samples.count > 24 {
            samples.removeFirst(samples.count - 24)
        }

        let hotAlert: HotProcess?
        if sample.cpuPercent >= 50 {
            let procs = await Task.detached(priority: .utility) {
                Self.readTopProcesses()
            }.value
            hotAlert = tracker.ingest(procs, at: .now)
        } else {
            hotAlert = tracker.ingest([], at: .now)
        }

        onSample(samples, hotAlert)
    }

    private func readSystemSample() -> SystemPulseSample {
        let cpu = readCPUPercent()
        let (usedGB, totalGB) = readMemoryGB()
        return SystemPulseSample(cpuPercent: cpu, ramUsedGB: usedGB, ramTotalGB: totalGB)
    }

    private func readCPUPercent() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        let u = UInt64(info.cpu_ticks.0)
        let s = UInt64(info.cpu_ticks.1)
        let i = UInt64(info.cpu_ticks.2)
        let n = UInt64(info.cpu_ticks.3)
        defer { prevCPUTicks = (u, s, i, n) }

        guard let prev = prevCPUTicks else { return 0 }
        let du = u &- prev.user
        let ds = s &- prev.system
        let di = i &- prev.idle
        let dn = n &- prev.nice
        let total = du + ds + di + dn
        guard total > 0 else { return 0 }
        return Double(du + ds + dn) / Double(total) * 100.0
    }

    private func readMemoryGB() -> (Double, Double) {
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824.0

        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vm = vm_statistics64_data_t()
        let kr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, totalGB) }
        let pageSize = Double(sysconf(_SC_PAGESIZE))
        let active = Double(vm.active_count + vm.wire_count + vm.compressor_page_count) * pageSize
        return (active / 1_073_741_824.0, totalGB)
    }

    private nonisolated static func readTopProcesses() -> [HotProcess] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Aceo", "pid,%cpu,comm", "-r"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return [] }
            return SystemPulseParser.parseTopProcesses(text)
        } catch {
            return []
        }
    }
}
