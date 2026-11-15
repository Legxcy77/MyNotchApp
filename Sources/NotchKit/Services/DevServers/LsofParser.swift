import Foundation

public struct DevServer: Equatable, Sendable, Identifiable {
    public var id: String { "\(pid):\(port)" }
    public var pid: Int32
    public var processName: String
    public var port: UInt16
    public var label: String

    public var url: URL {
        URL(string: "http://localhost:\(port)")!
    }

    public init(pid: Int32, processName: String, port: UInt16, label: String) {
        self.pid = pid
        self.processName = processName
        self.port = port
        self.label = label
    }
}

public enum LsofParser {
    private struct Key: Hashable {
        let pid: Int32
        let port: UInt16
    }

    public static func parse(
        _ output: String,
        excludedPID: Int32 = ProcessInfo.processInfo.processIdentifier,
        excludedPort: UInt16 = EventBusServer.configuredPort()
    ) -> [DevServer] {
        var currentPID: Int32?
        var currentProcess = "unknown"
        var seen = Set<Key>()
        var results: [DevServer] = []

        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value)
                currentProcess = "unknown"
            case "c":
                currentProcess = value
            case "n":
                guard let pid = currentPID, pid != excludedPID else { continue }
                guard let colonIdx = value.lastIndex(of: ":"),
                      let port = UInt16(value[value.index(after: colonIdx)...]),
                      port != excludedPort else { continue }
                let key = Key(pid: pid, port: port)
                if seen.insert(key).inserted {
                    results.append(DevServer(
                        pid: pid,
                        processName: currentProcess,
                        port: port,
                        label: mapLabel(process: currentProcess, port: port)
                    ))
                }
            default:
                continue
            }
        }

        return results.sorted { $0.port < $1.port }
    }

    private static func mapLabel(process: String, port: UInt16) -> String {
        let lower = process.lowercased()
        if lower.contains("next") { return "Next.js" }
        if lower.contains("vite") { return "Vite" }
        if lower.contains("dotnet") { return ".NET" }
        if lower.contains("python") || lower.contains("uvicorn") || lower.contains("gunicorn") { return "Python" }
        if lower.contains("ruby") || lower.contains("puma") { return "Ruby" }

        switch port {
        case 3000, 3001: return lower == "node" ? "Node / Next" : process
        case 5173, 5174: return "Vite"
        case 4200: return "Angular"
        case 4321: return "Astro"
        case 5000, 5001: return lower.contains("dotnet") ? ".NET" : "Dev (\(process))"
        case 8000, 8080, 8888: return "HTTP (\(process))"
        default: return process
        }
    }
}

