import Foundation

public struct AgentSession: Equatable, Sendable, Identifiable {
    public struct Key: Hashable, Sendable {
        public var source: String
        public var session: String

        public init(source: String, session: String) {
            self.source = source
            self.session = session
        }
    }

    public var id: Key { Key(source: source, session: session) }
    public var source: String
    public var session: String
    public var state: ActivityEvent.State
    public var title: String?
    public var cwd: String?
    public var startedAt: Date
    public var updatedAt: Date

    public init(
        source: String,
        session: String,
        state: ActivityEvent.State,
        title: String? = nil,
        cwd: String? = nil,
        startedAt: Date,
        updatedAt: Date
    ) {
        self.source = source
        self.session = session
        self.state = state
        self.title = title
        self.cwd = cwd
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    public var cwdBasename: String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    public var isActive: Bool {
        state == .working || state == .waiting
    }
}
