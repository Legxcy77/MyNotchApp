import Foundation
import Network

public struct DockerContainer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let image: String
    public let state: String
    public let status: String
    public let portsSummary: String

    public init(
        id: String,
        name: String,
        image: String,
        state: String,
        status: String,
        portsSummary: String
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.status = status
        self.portsSummary = portsSummary
    }
}

public enum DockerAction: Equatable, Sendable {
    case restart(DockerContainer)
    case pinLogs(DockerContainer)
}

public enum DockerContainerParser {
    public static func extractHTTPBody(from rawResponse: Data) -> Data? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = rawResponse.range(of: separator) else { return nil }
        return rawResponse.subdata(in: range.upperBound..<rawResponse.endIndex)
    }

    public static func parse(_ jsonData: Data) -> [DockerContainer] {
        guard let decoded = try? JSONDecoder().decode([RawDockerContainer].self, from: jsonData) else {
            return []
        }
        return decoded.map { raw in
            let cleanName = (raw.Names?.first ?? raw.Id)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            var seenPorts = Set<String>()
            var portLabels: [String] = []
            for p in raw.Ports ?? [] {
                let label: String
                if let pub = p.PublicPort {
                    label = "\(pub)→\(p.PrivatePort)"
                } else {
                    label = "\(p.PrivatePort)"
                }
                if seenPorts.insert(label).inserted {
                    portLabels.append(label)
                }
            }

            return DockerContainer(
                id: raw.Id,
                name: cleanName,
                image: raw.Image ?? "",
                state: raw.State ?? "running",
                status: raw.Status ?? "",
                portsSummary: portLabels.joined(separator: ", ")
            )
        }
    }
}

private struct RawDockerContainer: Decodable {
    let Id: String
    let Names: [String]?
    let Image: String?
    let State: String?
    let Status: String?
    let Ports: [RawDockerPort]?
}

private struct RawDockerPort: Decodable {
    let PrivatePort: Int
    let PublicPort: Int?
}

/// Queries Docker Engine API via Unix Domain Socket (`/var/run/docker.sock` or `~/.docker/run/docker.sock`)
/// only while the Notch is expanded (0% idle CPU).
public actor DockerGlanceMonitor {
    private let onUpdate: @MainActor ([DockerContainer]) -> Void
    private var pollingTask: Task<Void, Never>?
    private var isActive = false

    public init(onUpdate: @escaping @MainActor ([DockerContainer]) -> Void) {
        self.onUpdate = onUpdate
    }

    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        pollingTask?.cancel()
        pollingTask = nil

        guard active else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshOnce()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    public func refreshOnce() async {
        guard let socketPath = Self.resolvedSocketPath() else {
            await onUpdate([])
            return
        }
        let request = "GET /containers/json?all=false HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
        guard let response = await Self.sendUnixHTTP(socketPath: socketPath, request: request),
              let body = DockerContainerParser.extractHTTPBody(from: response) else {
            await onUpdate([])
            return
        }
        let containers = DockerContainerParser.parse(body)
        await onUpdate(containers)
    }

    public func restartContainer(id: String) async -> Bool {
        guard let socketPath = Self.resolvedSocketPath() else { return false }
        let request = "POST /containers/\(id)/restart HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        let response = await Self.sendUnixHTTP(socketPath: socketPath, request: request)
        await refreshOnce()
        return response != nil
    }

    private static func resolvedSocketPath() -> String? {
        let candidates = [
            "/var/run/docker.sock",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".docker/run/docker.sock").path,
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private static func sendUnixHTTP(socketPath: String, request: String) async -> Data? {
        await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.unix(path: socketPath)
            let conn = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.docker.sock")

            final class BufferBox: @unchecked Sendable {
                // Serialized strictly on `queue` (serial DispatchQueue).
                var data = Data()
                var resumed = false
            }
            let box = BufferBox()

            @Sendable func finish(_ result: Data?) {
                guard !box.resumed else { return }
                box.resumed = true
                conn.cancel()
                continuation.resume(returning: result)
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.send(content: Data(request.utf8), completion: .contentProcessed { err in
                        if err != nil {
                            finish(nil)
                            return
                        }
                        @Sendable func receiveNext() {
                            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, recErr in
                                if let data { box.data.append(data) }
                                if isComplete || recErr != nil {
                                    finish(box.data.isEmpty ? nil : box.data)
                                } else {
                                    receiveNext()
                                }
                            }
                        }
                        receiveNext()
                    })
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }

            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 2.5) {
                finish(box.data.isEmpty ? nil : box.data)
            }
        }
    }
}

