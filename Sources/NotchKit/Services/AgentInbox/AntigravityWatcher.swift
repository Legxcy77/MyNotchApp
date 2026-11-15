import CoreServices
import Foundation

public enum AntigravityTranscriptParser {
    public static func parseLatestEvent(from data: Data, sessionID: String) -> ActivityEvent? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.split(whereSeparator: \.isNewline)
        guard let lastLine = lines.last,
              let lineData = lastLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
            return nil
        }

        let type = (json["type"] as? String) ?? ""
        let status = (json["status"] as? String) ?? ""
        let toolCalls = json["tool_calls"] as? [[String: Any]]
        let firstToolName = toolCalls?.first?["name"] as? String
        let needsUserApproval = toolCalls?.contains { call in
            let name = call["name"] as? String
            if name == "ask_question" { return true }
            let args = (call["args"] as? [String: Any]) ?? (call["arguments"] as? [String: Any])
            if let bypass = args?["BypassSandbox"] as? Bool { return bypass }
            if let bypassStr = args?["BypassSandbox"] as? String { return bypassStr.lowercased() == "true" }
            return false
        } ?? false

        let state: ActivityEvent.State
        let title: String

        let firstArgs = (toolCalls?.first?["args"] as? [String: Any]) ?? (toolCalls?.first?["arguments"] as? [String: Any])
        let toolSummary = (firstArgs?["toolSummary"] as? String)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        let modifiedFiles: [String] = (toolCalls ?? []).compactMap { call in
            let name = call["name"] as? String ?? ""
            guard name == "edit_file" || name == "write_file" || name == "replace_file_content" || name == "multi_replace_file_content" else {
                return nil
            }
            let args = (call["args"] as? [String: Any]) ?? (call["arguments"] as? [String: Any])
            let raw = (args?["Path"] as? String) ?? (args?["TargetFile"] as? String)
            return raw?.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        }.filter { !$0.isEmpty }

        if status == "WAITING" || status == "PENDING" || status == "PENDING_APPROVAL" || status == "BLOCKED" {
            state = .waiting
            title = firstToolName.map { "Waiting: \($0)" } ?? "Waiting for Accept"
        } else if needsUserApproval && status != "ERROR" && status != "FAILED" {
            state = .waiting
            if firstToolName == "ask_question" {
                title = "Waiting for Answer"
            } else if let toolSummary, !toolSummary.isEmpty {
                title = "Waiting Approval · \(toolSummary)"
            } else {
                title = "Waiting for Approval"
            }
        } else if status == "ERROR" || status == "FAILED" {
            state = .failed
            title = "Agent step failed"
        } else if type == "PLANNER_RESPONSE" && status == "DONE" && (toolCalls == nil || toolCalls?.isEmpty == true) {
            state = .done
            title = "Antigravity finished"
        } else if let firstToolName {
            state = .working
            if let toolSummary, !toolSummary.isEmpty {
                title = toolSummary
            } else if let firstFile = modifiedFiles.first {
                title = "Editing \((firstFile as NSString).lastPathComponent)"
            } else {
                title = "Running \(firstToolName)"
            }
        } else if type == "USER_INPUT" || status == "RUNNING" || status == "IN_PROGRESS" {
            state = .working
            title = "Thinking…"
        } else {
            state = .working
            title = type.isEmpty ? "Working" : type
        }

        return ActivityEvent(
            source: "antigravity",
            session: sessionID,
            state: state,
            title: title,
            cwd: nil,
            modifiedFiles: modifiedFiles
        )
    }
}

/// Event-driven FSEvents watcher for `~/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl`.
/// Zero polling when idle; emits `ActivityEvent` whenever an Antigravity session updates.
public final class AntigravityWatcher: @unchecked Sendable {
    // Thread-safety: `stream` and `lastEmitted` are mutated only on `queue` (serial DispatchQueue).
    private let brainDir: URL
    private let onEvent: @MainActor (ActivityEvent) -> Void
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.antigravity.watcher")
    private var stream: FSEventStreamRef?
    private var lastEmitted: [String: (ActivityEvent.State, String?)] = [:]

    public init(
        brainDir: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity/brain", isDirectory: true),
        onEvent: @escaping @MainActor (ActivityEvent) -> Void
    ) {
        self.brainDir = brainDir
        self.onEvent = onEvent
    }

    deinit {
        stop()
    }

    public func start() {
        queue.async { [weak self] in
            self?.startStream()
        }
    }

    public func stop() {
        queue.sync {
            if let stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                self.stream = nil
            }
        }
    }

    private func startStream() {
        guard stream == nil, FileManager.default.fileExists(atPath: brainDir.path) else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<AntigravityWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            watcher.handlePaths(Array(paths.prefix(numEvents)))
        }

        let pathsToWatch = [brainDir.path] as CFArray
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let fsStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(fsStream, queue)
        FSEventStreamStart(fsStream)
        stream = fsStream
    }

    private func handlePaths(_ paths: [String]) {
        let transcripts = paths.filter { $0.hasSuffix("transcript.jsonl") }
        for path in Set(transcripts) {
            let url = URL(fileURLWithPath: path)
            // .../<sessionID>/.system_generated/logs/transcript.jsonl
            let sessionID = url
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .lastPathComponent

            guard let tailData = readTail(of: url, maxBytes: 16384),
                  let event = AntigravityTranscriptParser.parseLatestEvent(from: tailData, sessionID: sessionID) else {
                continue
            }

            let prev = lastEmitted[sessionID]
            if prev?.0 == event.state && prev?.1 == event.title {
                continue
            }
            lastEmitted[sessionID] = (event.state, event.title)
            let emit = onEvent
            Task { @MainActor in
                emit(event)
            }
        }
    }

    private func readTail(of url: URL, maxBytes: UInt64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let fileSize = (try? handle.seekToEnd()) ?? 0
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: offset)
        return try? handle.readToEnd()
    }
}

