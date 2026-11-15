import Foundation

@MainActor
public final class DevServerMonitor {
    private let onUpdate: @MainActor ([DevServer]) -> Void
    private var pollTask: Task<Void, Never>?
    private var isActive = false

    public init(onUpdate: @escaping @MainActor ([DevServer]) -> Void) {
        self.onUpdate = onUpdate
    }

    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        pollTask?.cancel()
        pollTask = nil

        guard active else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled, let self {
                await self.refreshOnce()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    public enum TerminationResult: Equatable, Sendable {
        case terminated
        case unsafePID
        case permissionDenied
        case notFound
        case timedOut
    }

    public func refreshOnce() async {
        let (lsofOut, psOut) = await Task.detached(priority: .utility) {
            (Self.runLsof(), Self.runPs())
        }.value
        let rawServers = LsofParser.parse(lsofOut)
        let psMap = PsOutputParser.parse(psOut)
        let enriched = ProcessInspector.enrich(servers: rawServers, psMap: psMap)
        onUpdate(enriched)
    }

    /// Rejects invalid PIDs, init/launchd (PID 1), and the current app process.
    nonisolated public static func isSafeToTerminate(
        pid: Int32,
        selfPID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> Bool {
        pid > 1 && pid != selfPID
    }

    /// Gracefully terminates a dev server with SIGTERM.
    /// Does not escalate to SIGKILL unless `forceEscalation` is explicitly requested.
    @discardableResult
    public static func killServer(pid: Int32, forceEscalation: Bool = false) async -> TerminationResult {
        guard isSafeToTerminate(pid: pid) else { return .unsafePID }
        return await Task.detached(priority: .userInitiated) {
            if kill(pid, SIGTERM) != 0 {
                switch errno {
                case EPERM: return .permissionDenied
                case ESRCH: return .notFound
                default: return .timedOut
                }
            }
            let deadline = ContinuousClock.now + .seconds(3)
            while ContinuousClock.now < deadline {
                if kill(pid, 0) != 0 { return .terminated }
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard forceEscalation else {
                return kill(pid, 0) != 0 ? .terminated : .timedOut
            }
            _ = kill(pid, SIGKILL)
            return .terminated
        }.value
    }

    private nonisolated static func runPs() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,user=,state=,etime=,command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private nonisolated static func runLsof() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-nP", "-F", "pcn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

