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

    public func refreshOnce() async {
        let output = await Task.detached(priority: .utility) {
            Self.runLsof()
        }.value
        let servers = LsofParser.parse(output)
        onUpdate(servers)
    }

    public static func killServer(pid: Int32) async {
        await Task.detached(priority: .userInitiated) {
            guard kill(pid, SIGTERM) == 0 else { return }
            let deadline = ContinuousClock.now + .seconds(3)
            while ContinuousClock.now < deadline {
                if kill(pid, 0) != 0 { return }
                try? await Task.sleep(for: .milliseconds(200))
            }
            _ = kill(pid, SIGKILL)
        }.value
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

