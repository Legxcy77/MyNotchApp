import Foundation
import Network

public final class EventBusServer: @unchecked Sendable {
    // @unchecked Sendable justification: `listener` and `queue` are confined to `queue`,
    // and `router` / `onAction` are immutable Sendable values set once in init.
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.EventBus")
    private let router: EventBusRouter
    private let onAction: @MainActor @Sendable (EventBusAction) -> Void
    private var listener: NWListener?

    public let port: UInt16

    public init(
        port: UInt16 = EventBusServer.configuredPort(),
        token: String,
        onAction: @escaping @MainActor @Sendable (EventBusAction) -> Void
    ) {
        self.port = port
        self.router = EventBusRouter(token: token)
        self.onAction = onAction
    }

    public static func configuredPort() -> UInt16 {
        if let env = ProcessInfo.processInfo.environment["MYNOTCH_PORT"], let p = UInt16(env), p > 0 {
            return p
        }
        let saved = UserDefaults.standard.integer(forKey: "eventBusPort")
        if saved > 0, saved <= Int(UInt16.max) { return UInt16(saved) }
        return 7777
    }

    public func start() throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: nwPort
        )

        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data { accumulated.append(data) }

            switch HTTPRequestParser.parse(accumulated) {
            case .complete(let request):
                let result = self.router.handle(request)
                if let action = result.action {
                    Task { @MainActor in self.onAction(action) }
                }
                self.sendAndClose(result.response, on: connection)
            case .invalid:
                let bad = HTTPResponse(statusCode: 400, reason: "Bad Request", json: #"{"error":"malformed_http"}"#)
                self.sendAndClose(bad, on: connection)
            case .incomplete:
                if isComplete || error != nil {
                    let bad = HTTPResponse(statusCode: 400, reason: "Bad Request", json: #"{"error":"incomplete_http"}"#)
                    self.sendAndClose(bad, on: connection)
                } else {
                    self.receive(on: connection, buffer: accumulated)
                }
            }
        }
    }

    private func sendAndClose(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

