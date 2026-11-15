import Foundation

public struct QuickTaskItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool

    public init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public struct NotesAndTasksPayload: Codable, Equatable, Sendable {
    public var note: String
    public var tasks: [QuickTaskItem]

    public init(note: String = "", tasks: [QuickTaskItem] = []) {
        self.note = note
        self.tasks = tasks
    }
}

public enum QuickNotesStore {
    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent("MyNotchApp", isDirectory: true)
            .appendingPathComponent("notes-tasks.json", isDirectory: false)
    }

    public static func load() -> NotesAndTasksPayload {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(NotesAndTasksPayload.self, from: data) else {
            return NotesAndTasksPayload()
        }
        return payload
    }

    public static func save(_ payload: NotesAndTasksPayload) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

