import CoreServices
import Foundation

public final class GitGlanceMonitor: @unchecked Sendable {
    // @unchecked Sendable justification: `stream`, `watchedRoot`, and `debounceItem`
    // are exclusively accessed on `queue`.
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.GitGlance")
    private let onUpdate: @MainActor @Sendable (GitStatus?) -> Void
    private var stream: FSEventStreamRef?
    private var watchedRoot: String?
    private var debounceItem: DispatchWorkItem?

    public init(onUpdate: @escaping @MainActor @Sendable (GitStatus?) -> Void) {
        self.onUpdate = onUpdate
    }

    deinit {
        stop()
    }

    public func watch(cwd: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let root = Self.gitTopLevel(for: cwd) else {
                self.stopLocked()
                Task { @MainActor in self.onUpdate(nil) }
                return
            }
            if self.watchedRoot == root {
                self.refreshLocked(root: root)
                return
            }
            self.stopLocked()
            self.watchedRoot = root
            self.startStreamLocked(root: root)
            self.refreshLocked(root: root)
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func stopLocked() {
        debounceItem?.cancel()
        debounceItem = nil
        watchedRoot = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func startStreamLocked(root: String) {
        let paths = [root, "\(root)/.git"] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let monitor = Unmanaged<GitGlanceMonitor>.fromOpaque(info).takeUnretainedValue()
                monitor.scheduleRefresh()
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else {
            return
        }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func scheduleRefresh() {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let root = self.watchedRoot else { return }
            self.refreshLocked(root: root)
        }
        debounceItem = item
        queue.asyncAfter(deadline: .now() + .milliseconds(250), execute: item)
    }

    private func refreshLocked(root: String) {
        let output = Self.runGit(args: ["-C", root, "status", "--porcelain=v2", "--branch"])
        let status = output.flatMap { GitStatusParser.parsePorcelainV2($0, repoRoot: root) }
        Task { @MainActor in
            self.onUpdate(status)
        }
    }

    private static func gitTopLevel(for cwd: String) -> String? {
        runGit(args: ["-C", cwd, "rev-parse", "--show-toplevel"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runGit(args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

