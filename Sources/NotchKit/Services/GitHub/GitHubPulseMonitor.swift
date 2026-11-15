import Foundation

@MainActor
public final class GitHubPulseMonitor {
    private let onUpdate: @MainActor ([PullRequestPulse], _ changes: [PullRequestPulse]) -> Void
    private var task: Task<Void, Never>?
    private var previous: [PullRequestPulse] = []
    private var hasSeeded = false

    public init(onUpdate: @escaping @MainActor ([PullRequestPulse], [PullRequestPulse]) -> Void) {
        self.onUpdate = onUpdate
    }

    isolated deinit {
        task?.cancel()
    }

    public func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func pollOnce() async {
        guard let ghPath = Self.resolveGHPath() else { return }
        let fetched = await Task.detached(priority: .utility) {
            Self.fetchAll(ghPath: ghPath)
        }.value

        let changes = hasSeeded ? GitHubPulseParser.diffTransitions(previous: previous, current: fetched) : []
        hasSeeded = true
        previous = fetched
        onUpdate(fetched, changes)
    }

    private nonisolated static func resolveGHPath() -> String? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private nonisolated static func fetchAll(ghPath: String) -> [PullRequestPulse] {
        var result: [PullRequestPulse] = []
        if let authoredData = runGH(ghPath: ghPath, args: ["api", "search/issues?q=is:pr+is:open+author:@me&per_page=10"]) {
            result.append(contentsOf: GitHubPulseParser.parseSearchItems(authoredData, isReviewRequest: false))
        }
        if let reviewData = runGH(ghPath: ghPath, args: ["api", "search/issues?q=is:pr+is:open+review-requested:@me&per_page=10"]) {
            result.append(contentsOf: GitHubPulseParser.parseSearchItems(reviewData, isReviewRequest: true))
        }
        return result
    }

    private nonisolated static func runGH(ghPath: String, args: [String]) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ghPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return p.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }
}

