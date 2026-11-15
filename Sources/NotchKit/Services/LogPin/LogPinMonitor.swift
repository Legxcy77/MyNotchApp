import Foundation

public final class LogPinMonitor: @unchecked Sendable {
    // @unchecked Sendable justification: `fileSource`, `fileHandle`, `process`,
    // and `currentLabel` are exclusively mutated on `queue`.
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.LogPin")
    private let onMatch: @MainActor @Sendable (String, String) -> Void
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?
    private var process: Process?
    private var currentLabel: String?

    public init(onMatch: @escaping @MainActor @Sendable (String, String) -> Void) {
        self.onMatch = onMatch
    }

    deinit {
        unpin()
    }

    public func pinFile(path: String, pattern: String = LogLineMatcher.defaultPattern) {
        let expanded = (path as NSString).expandingTildeInPath
        let matcher = LogLineMatcher(pattern: pattern)
        let label = (expanded as NSString).lastPathComponent

        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked()
            guard let handle = FileHandle(forReadingAtPath: expanded) else { return }
            _ = try? handle.seekToEnd()
            self.fileHandle = handle
            self.currentLabel = label

            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: handle.fileDescriptor,
                eventMask: [.write, .extend],
                queue: self.queue
            )
            src.setEventHandler { [weak self] in
                guard let self, let data = try? handle.readToEnd(), !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                self.emitMatches(in: text, matcher: matcher, label: label)
            }
            src.setCancelHandler {
                try? handle.close()
            }
            self.fileSource = src
            src.resume()
        }
    }

    public func pinCommand(_ command: String, pattern: String = LogLineMatcher.defaultPattern) {
        let matcher = LogLineMatcher(pattern: pattern)
        let label = String(command.prefix(24))

        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked()
            self.currentLabel = label

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-lc", command]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
                let data = fh.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                self?.emitMatches(in: text, matcher: matcher, label: label)
            }
            p.terminationHandler = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
            }
            do {
                try p.run()
                self.process = p
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
    }

    public func unpin() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func emitMatches(in text: String, matcher: LogLineMatcher, label: String) {
        for line in matcher.matchingLines(in: text) {
            Task { @MainActor in
                self.onMatch(label, line)
            }
        }
    }

    private func stopLocked() {
        fileSource?.cancel()
        fileSource = nil
        fileHandle = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        currentLabel = nil
    }
}

