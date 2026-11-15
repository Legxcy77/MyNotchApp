import Foundation

public enum DockerEngineAvailability: Equatable, Sendable, Codable {
    case available
    case notInstalled
    case daemonStopped
    case unknown
}

public enum ServiceHealthState: String, Equatable, Sendable, Codable {
    case running
    case stopped
    case crashed
    case restarting
    case unhealthy
    case unknown
}

public struct DockerServiceHealth: Equatable, Sendable, Identifiable {
    public var id: String // Container ID (never rely on name alone)
    public var name: String
    public var image: String
    public var state: ServiceHealthState
    public var restartCount: Int
    public var healthStatus: String?
    public var exposedPorts: [String]
    public var dependsOn: [String]
    public var affectedDependency: String?

    public init(
        id: String,
        name: String,
        image: String,
        state: ServiceHealthState,
        restartCount: Int = 0,
        healthStatus: String? = nil,
        exposedPorts: [String] = [],
        dependsOn: [String] = [],
        affectedDependency: String? = nil
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.restartCount = restartCount
        self.healthStatus = healthStatus
        self.exposedPorts = exposedPorts
        self.dependsOn = dependsOn
        self.affectedDependency = affectedDependency
    }
}

public struct EnvironmentHealthSummary: Equatable, Sendable {
    public var engineAvailability: DockerEngineAvailability
    public var services: [DockerServiceHealth]

    public var unhealthyCount: Int {
        services.count { $0.state == .crashed || $0.state == .unhealthy || $0.state == .restarting }
    }
}

/// Evaluates local service & Docker container health without ever auto-restarting containers
/// or misclassifying engine unavailability as stopped containers.
public enum ServiceHealthInspector {
    public static func evaluate(
        containers: [DockerContainer],
        engineAvailability: DockerEngineAvailability,
        dependencyMap: [String: [String]] = [:]
    ) -> EnvironmentHealthSummary {
        guard engineAvailability == .available else {
            return EnvironmentHealthSummary(engineAvailability: engineAvailability, services: [])
        }

        var mapped = containers.map { c -> DockerServiceHealth in
            let state = mapState(rawState: c.state, statusText: c.status)
            let deps = dependencyMap[c.name] ?? []
            return DockerServiceHealth(
                id: c.id,
                name: c.name,
                image: c.image,
                state: state,
                restartCount: extractRestartCount(from: c.status),
                healthStatus: extractHealth(from: c.status),
                exposedPorts: c.portsSummary.isEmpty ? [] : [c.portsSummary],
                dependsOn: deps
            )
        }

        let unhealthyNames = Set(mapped.filter { $0.state != .running }.map(\.name))
        for i in mapped.indices {
            if let downDep = mapped[i].dependsOn.first(where: { unhealthyNames.contains($0) }) {
                mapped[i].affectedDependency = downDep
            }
        }

        return EnvironmentHealthSummary(engineAvailability: .available, services: mapped)
    }

    private static func mapState(rawState: String, statusText: String) -> ServiceHealthState {
        let s = rawState.lowercased()
        let st = statusText.lowercased()
        if st.contains("unhealthy") { return .unhealthy }
        switch s {
        case "running": return .running
        case "restarting": return .restarting
        case "exited", "dead":
            if st.contains("exited (0)") { return .stopped }
            return .crashed
        case "created", "paused":
            return .stopped
        default:
            return .unknown
        }
    }

    private static func extractHealth(from statusText: String) -> String? {
        let lower = statusText.lowercased()
        if lower.contains("(healthy)") { return "healthy" }
        if lower.contains("(unhealthy)") { return "unhealthy" }
        if lower.contains("(health: starting)") { return "starting" }
        return nil
    }

    private static func extractRestartCount(from statusText: String) -> Int {
        guard statusText.lowercased().contains("restarting") else { return 0 }
        return 1
    }
}
