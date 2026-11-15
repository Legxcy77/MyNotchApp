import Foundation

public enum ScreenshotDetector {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff"]
    private static let prefixes = ["screenshot", "screen shot", "ภาพถ่ายหน้าจอ"]

    public static func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix(".") else { return false }
        guard imageExtensions.contains(url.pathExtension.lowercased()) else { return false }
        let lower = name.lowercased()
        return prefixes.contains { lower.hasPrefix($0) }
    }

    public static func diffNewScreenshots(previous: Set<URL>, current: [URL]) -> [URL] {
        current
            .map(\.standardizedFileURL)
            .filter { isScreenshotFile($0) && !previous.contains($0) }
    }
}

public final class ScreenshotWatcher: @unchecked Sendable {
    // @unchecked Sendable justification: `source`, `knownFiles`, `debounceItem`, and `fd`
    // are exclusively accessed on `queue`.
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.ScreenshotWatcher")
    private let directory: URL
    private let onNewScreenshot: @MainActor @Sendable (URL) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var knownFiles: Set<URL> = []
    private var debounceItem: DispatchWorkItem?

    public init(
        directory: URL = ScreenshotWatcher.resolveDirectory(),
        onNewScreenshot: @escaping @MainActor @Sendable (URL) -> Void
    ) {
        self.directory = directory
        self.onNewScreenshot = onNewScreenshot
    }

    deinit {
        stop()
    }

    public static func resolveDirectory() -> URL {
        if let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !custom.isEmpty {
            let expanded = (custom as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, self.source == nil else { return }
            self.knownFiles = Set(self.listFiles().map(\.standardizedFileURL))

            let descriptor = open(self.directory.path, O_EVTONLY)
            guard descriptor >= 0 else { return }
            self.fd = descriptor

            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: .write,
                queue: self.queue
            )
            src.setEventHandler { [weak self] in
                self?.scheduleScan()
            }
            src.setCancelHandler { [weak self] in
                if let fd = self?.fd, fd >= 0 {
                    close(fd)
                    self?.fd = -1
                }
            }
            self.source = src
            src.resume()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.debounceItem?.cancel()
            self?.debounceItem = nil
            self?.source?.cancel()
            self?.source = nil
        }
    }

    private func scheduleScan() {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.scanForNewScreenshots()
        }
        debounceItem = item
        queue.asyncAfter(deadline: .now() + .milliseconds(150), execute: item)
    }

    private func scanForNewScreenshots() {
        let current = listFiles()
        let added = ScreenshotDetector.diffNewScreenshots(previous: knownFiles, current: current)
        knownFiles = Set(current.map(\.standardizedFileURL))

        for url in added {
            Task { @MainActor in
                self.onNewScreenshot(url)
            }
        }
    }

    private func listFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
    }
}

