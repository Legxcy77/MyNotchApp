import Foundation

public struct ActivityEvent: Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case working, waiting, done, failed
    }

    public var source: String
    public var session: String
    public var state: State
    public var title: String?
    public var cwd: String?

    public init(source: String, session: String, state: State, title: String? = nil, cwd: String? = nil) {
        self.source = source
        self.session = session
        self.state = state
        self.title = title
        self.cwd = cwd
    }
}

public enum EventBusAction: Equatable, Sendable {
    case postToast(Toast)
    case activity(ActivityEvent)
}

public struct EventBusResult: Equatable, Sendable {
    public var response: HTTPResponse
    public var action: EventBusAction?
}

public struct EventBusRouter: Sendable {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func handle(_ request: HTTPRequest) -> EventBusResult {
        guard isAuthorized(request) else {
            return EventBusResult(
                response: HTTPResponse(statusCode: 401, reason: "Unauthorized", json: #"{"error":"unauthorized"}"#),
                action: nil
            )
        }

        switch (request.method, request.path) {
        case ("GET", "/health"):
            return EventBusResult(
                response: HTTPResponse(statusCode: 200, reason: "OK", json: #"{"ok":true}"#),
                action: nil
            )
        case ("POST", "/toast"):
            return handleToast(request.body)
        case ("POST", "/progress"):
            return handleProgress(request.body)
        case ("POST", "/activity"):
            return handleActivity(request.body)
        default:
            return EventBusResult(
                response: HTTPResponse(statusCode: 404, reason: "Not Found", json: #"{"error":"not_found"}"#),
                action: nil
            )
        }
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        guard let header = request.header("authorization") else { return false }
        let prefix = "Bearer "
        guard header.hasPrefix(prefix) else { return false }
        let provided = String(header.dropFirst(prefix.count))
        return provided == token && !token.isEmpty
    }

    private func handleToast(_ body: Data) -> EventBusResult {
        guard let payload = try? JSONDecoder().decode(ToastPayload.self, from: body) else {
            return badRequest("invalid_toast_payload")
        }
        let defaultTTL = payload.errorLog != nil ? 8.0 : 3.0
        let toast = Toast(
            key: payload.key,
            title: payload.title,
            subtitle: payload.subtitle,
            symbol: payload.symbol ?? "bell.fill",
            tint: Self.parseTint(payload.tint),
            priority: Self.parsePriority(payload.priority),
            duration: .seconds(payload.ttl ?? defaultTTL),
            action: payload.bundleId.flatMap { $0.isEmpty ? nil : .activateApp(bundleID: $0) },
            errorLog: payload.errorLog
        )
        return EventBusResult(
            response: HTTPResponse(statusCode: 200, reason: "OK", json: #"{"ok":true}"#),
            action: .postToast(toast)
        )
    }

    private func handleProgress(_ body: Data) -> EventBusResult {
        guard let payload = try? JSONDecoder().decode(ProgressPayload.self, from: body) else {
            return badRequest("invalid_progress_payload")
        }
        let clamped = min(max(payload.value, 0), 1)
        let pct = Int((clamped * 100).rounded())
        let subtitle = payload.subtitle.map { "\(pct)% · \($0)" } ?? "\(pct)%"
        let done = clamped >= 1.0

        let toast = Toast(
            key: payload.key,
            title: payload.title,
            subtitle: subtitle,
            symbol: done ? "checkmark" : "arrow.triangle.2.circlepath",
            tint: done ? .success : .info,
            priority: .normal,
            duration: done ? .seconds(1.5) : .seconds(15)
        )
        return EventBusResult(
            response: HTTPResponse(statusCode: 200, reason: "OK", json: #"{"ok":true}"#),
            action: .postToast(toast)
        )
    }

    private func handleActivity(_ body: Data) -> EventBusResult {
        guard let payload = try? JSONDecoder().decode(ActivityPayload.self, from: body) else {
            return badRequest("invalid_activity_payload")
        }
        let event = ActivityEvent(
            source: payload.source,
            session: payload.session,
            state: payload.state,
            title: payload.title,
            cwd: payload.cwd
        )
        return EventBusResult(
            response: HTTPResponse(statusCode: 200, reason: "OK", json: #"{"ok":true}"#),
            action: .activity(event)
        )
    }

    private func badRequest(_ code: String) -> EventBusResult {
        EventBusResult(
            response: HTTPResponse(statusCode: 400, reason: "Bad Request", json: #"{"error":"\#(code)"}"#),
            action: nil
        )
    }

    private static func parseTint(_ raw: String?) -> Toast.Tint {
        switch raw?.lowercased() {
        case "success", "ok", "green": .success
        case "failure", "fail", "error", "red": .failure
        case "waiting", "warn", "warning", "orange": .waiting
        case "info", "blue": .info
        default: .neutral
        }
    }

    private static func parsePriority(_ raw: String?) -> Toast.Priority {
        switch raw?.lowercased() {
        case "low": .low
        case "high": .high
        case "critical": .critical
        default: .normal
        }
    }
}

private struct ToastPayload: Decodable {
    var title: String
    var subtitle: String?
    var symbol: String?
    var tint: String?
    var priority: String?
    var ttl: Double?
    var key: String?
    var bundleId: String?
    var errorLog: String?
}

private struct ProgressPayload: Decodable {
    var key: String
    var title: String
    var value: Double
    var subtitle: String?
}

private struct ActivityPayload: Decodable {
    var source: String
    var session: String
    var state: ActivityEvent.State
    var title: String?
    var cwd: String?
}

