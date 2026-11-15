import Foundation

public struct Toast: Equatable, Sendable, Identifiable {
    public enum Tint: String, Sendable, Codable, CaseIterable { case neutral, success, failure, waiting, info }

    public enum Priority: Int, Sendable, Codable, Comparable {
        case low, normal, high, critical
        public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    public enum Action: Equatable, Sendable, Codable {
        case activateApp(bundleID: String)
        case openURL(URL)
        case killProcess(pid: Int32)
    }

    public let id: UUID
    /// Toasts sharing a key replace each other in place (progress updates, repeated alerts).
    public var key: String?
    public var title: String
    public var subtitle: String?
    public var symbol: String
    public var tint: Tint
    public var priority: Priority
    public var duration: Duration
    public var action: Action?
    public var thumbnailPath: String?
    public var errorLog: String?

    public init(id: UUID = UUID(), key: String? = nil, title: String, subtitle: String? = nil,
                symbol: String = "bell.fill", tint: Tint = .neutral, priority: Priority = .normal,
                duration: Duration = .seconds(3), action: Action? = nil, thumbnailPath: String? = nil,
                errorLog: String? = nil) {
        self.id = id
        self.key = key
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.priority = priority
        self.duration = duration
        self.action = action
        self.thumbnailPath = thumbnailPath
        self.errorLog = errorLog
    }
}

