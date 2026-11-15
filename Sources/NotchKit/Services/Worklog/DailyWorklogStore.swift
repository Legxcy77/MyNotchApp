import Foundation

public enum WorklogRange: Equatable, Sendable, Hashable {
    case today
    case yesterday
    case last7Days
    case last30Days
    case lastYear
    case specificDay(String)

    public var label: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .last7Days: return "7D"
        case .last30Days: return "30D"
        case .lastYear: return "1Y"
        case .specificDay(let key): return key
        }
    }

    public static var quickPresets: [WorklogRange] {
        [.today, .yesterday, .last7Days, .last30Days, .lastYear]
    }
}

public struct WorklogEntry: Identifiable, Equatable, Sendable, Codable {
    public enum Kind: String, Equatable, Sendable, Codable {
        case agentWorking
        case agentWaiting
        case agentDone
        case agentFailed
        case buildRunning
        case buildPassed
        case buildFailed
        case devServerReady
        case devServerError
        case command
    }

    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public let title: String
    public let detail: String?
    public let project: String?
    public let duration: TimeInterval?
    public let exitCode: Int32?
    public var aiExplanation: String?
    public let fingerprint: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: Kind,
        title: String,
        detail: String? = nil,
        project: String? = nil,
        duration: TimeInterval? = nil,
        exitCode: Int32? = nil,
        aiExplanation: String? = nil,
        fingerprint: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.detail = detail
        self.project = project
        self.duration = duration
        self.exitCode = exitCode
        self.aiExplanation = aiExplanation
        self.fingerprint = fingerprint
    }

    public var isSuccess: Bool {
        switch kind {
        case .agentDone, .buildPassed, .devServerReady: return true
        case .command: return (exitCode ?? 0) == 0
        default: return false
        }
    }

    public var isFailure: Bool {
        switch kind {
        case .agentFailed, .buildFailed, .devServerError: return true
        case .command: return (exitCode ?? 0) != 0
        default: return false
        }
    }
}

/// Persists developer worklog entries into daily JSON files (`~/.mynotch/worklog/YYYY-MM-DD.json`)
/// so each day starts clean while preserving historical evidence across days, weeks, months, and years.
public struct DailyWorklogStore: Sendable {
    public let directory: URL

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mynotch", isDirectory: true)
            .appendingPathComponent("worklog", isDirectory: true)
    }

    public init(directory: URL = defaultDirectory) {
        self.directory = directory
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public func append(_ entry: WorklogEntry, calendar: Calendar = .current) {
        let key = Self.dayKey(for: entry.timestamp, calendar: calendar)
        var entries = loadDay(dayKey: key)

        if let fp = entry.fingerprint,
           let latest = entries.first,
           latest.fingerprint == fp && latest.kind == entry.kind && latest.title == entry.title {
            return
        }

        entries.insert(entry, at: 0)
        if entries.count > 500 {
            entries.removeLast(entries.count - 500)
        }
        saveDay(entries, dayKey: key)
    }

    public func updateAIExplanation(
        entryID: UUID,
        on date: Date,
        explanation: String,
        calendar: Calendar = .current
    ) {
        let key = Self.dayKey(for: date, calendar: calendar)
        var entries = loadDay(dayKey: key)
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[idx].aiExplanation = explanation
        saveDay(entries, dayKey: key)
    }

    public func loadDay(dayKey: String) -> [WorklogEntry] {
        let url = fileURL(for: dayKey)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entries = try? decoder.decode([WorklogEntry].self, from: data) else { return [] }
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    public func load(
        range: WorklogRange,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> [WorklogEntry] {
        switch range {
        case .today:
            return loadDay(dayKey: Self.dayKey(for: now, calendar: calendar))
        case .yesterday:
            let yday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return loadDay(dayKey: Self.dayKey(for: yday, calendar: calendar))
        case .specificDay(let key):
            return loadDay(dayKey: key)
        case .last7Days:
            return loadLastDays(7, relativeTo: now, calendar: calendar)
        case .last30Days:
            return loadLastDays(30, relativeTo: now, calendar: calendar)
        case .lastYear:
            return loadLastDays(366, relativeTo: now, calendar: calendar)
        }
    }

    public func availableDays() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted(by: >)
    }

    public func clear(dayKey: String) {
        let url = fileURL(for: dayKey)
        try? FileManager.default.removeItem(at: url)
    }

    private func loadLastDays(_ count: Int, relativeTo now: Date, calendar: Calendar) -> [WorklogEntry] {
        let cutoff = calendar.date(byAdding: .day, value: -(count - 1), to: calendar.startOfDay(for: now)) ?? now
        let cutoffKey = Self.dayKey(for: cutoff, calendar: calendar)
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        let matchingDays = availableDays().filter { $0 >= cutoffKey && $0 <= todayKey }

        var all: [WorklogEntry] = []
        for key in matchingDays {
            all.append(contentsOf: loadDay(dayKey: key))
        }
        return all.sorted { $0.timestamp > $1.timestamp }
    }

    private func fileURL(for dayKey: String) -> URL {
        directory.appendingPathComponent("\(dayKey).json", isDirectory: false)
    }

    private func saveDay(_ entries: [WorklogEntry], dayKey: String) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: fileURL(for: dayKey), options: .atomic)
        } catch {
            // Ignore disk write errors to keep UI/state non-blocking
        }
    }
}
