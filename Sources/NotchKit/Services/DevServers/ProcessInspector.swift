import Foundation

public struct PsProcessInfo: Equatable, Sendable {
    public var pid: Int32
    public var parentPID: Int32
    public var user: String
    public var state: String
    public var elapsed: String
    public var command: String
}

public struct PortConflict: Equatable, Sendable, Identifiable {
    public var id: UInt16 { port }
    public var port: UInt16
    public var servers: [DevServer]
}

public enum PsOutputParser {
    /// Parses `ps -axo pid=,ppid=,user=,state=,etime=,command=` output.
    public static func parse(_ output: String) -> [Int32: PsProcessInfo] {
        var map: [Int32: PsProcessInfo] = [:]
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // Split first 5 whitespace-separated fields, keeping the rest as `command`
            var parts: [Substring] = []
            var idx = line.startIndex
            while idx < line.endIndex && parts.count < 5 {
                while idx < line.endIndex && line[idx].isWhitespace {
                    idx = line.index(after: idx)
                }
                guard idx < line.endIndex else { break }
                let start = idx
                while idx < line.endIndex && !line[idx].isWhitespace {
                    idx = line.index(after: idx)
                }
                parts.append(line[start..<idx])
            }
            guard parts.count == 5 else { continue }
            while idx < line.endIndex && line[idx].isWhitespace {
                idx = line.index(after: idx)
            }
            let command = String(line[idx...])
            guard let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else { continue }

            map[pid] = PsProcessInfo(
                pid: pid,
                parentPID: ppid,
                user: String(parts[2]),
                state: String(parts[3]),
                elapsed: String(parts[4]),
                command: command
            )
        }
        return map
    }
}

public enum ProcessInspector {
    public static func enrich(
        servers: [DevServer],
        psMap: [Int32: PsProcessInfo],
        currentUser: String = NSUserName()
    ) -> [DevServer] {
        servers.map { server in
            var updated = server
            if let info = psMap[server.pid] {
                updated.parentPID = info.parentPID
                updated.commandLine = info.command
                updated.startTime = info.elapsed
                updated.associatedProject = inferProject(command: info.command)
                updated.isProtected = isProtectedProcess(
                    pid: server.pid,
                    processName: server.processName,
                    ownerUser: info.user,
                    currentUser: currentUser
                )
            } else {
                // Process disappeared between lsof and ps, or process metadata is inaccessible
                updated.isProtected = isProtectedProcess(
                    pid: server.pid,
                    processName: server.processName,
                    ownerUser: nil,
                    currentUser: currentUser
                )
            }
            return updated
        }
    }

    public static func detectPortConflicts(_ servers: [DevServer]) -> [PortConflict] {
        let grouped = Dictionary(grouping: servers, by: \.port)
        return grouped.compactMap { port, group in
            let distinctPIDs = Set(group.map(\.pid))
            guard distinctPIDs.count >= 2 else { return nil }
            return PortConflict(port: port, servers: group.sorted { $0.pid < $1.pid })
        }
        .sorted { $0.port < $1.port }
    }

    public static func inferProject(command: String) -> String? {
        // 1. node_modules/.bin/<tool> -> parent of node_modules
        if let range = command.range(of: "/node_modules/") {
            let prefix = String(command[..<range.lowerBound])
            let lastToken = prefix.split(separator: " ").last.map(String.init) ?? prefix
            let name = (lastToken as NSString).lastPathComponent
            if !name.isEmpty && name != "/" {
                return name
            }
        }
        // 2. .csproj or .dll or package.json path
        for token in command.split(separator: " ").map(String.init) {
            if token.hasSuffix(".csproj") || token.hasSuffix(".dll") {
                let dir = (token as NSString).deletingLastPathComponent
                let name = (dir as NSString).lastPathComponent
                if !name.isEmpty && name != "bin" && name != "Release" && name != "Debug" && !name.hasPrefix("net") {
                    return name
                }
                let file = ((token as NSString).lastPathComponent as NSString).deletingPathExtension
                if !file.isEmpty { return file }
            }
        }
        return nil
    }

    private static func isProtectedProcess(
        pid: Int32,
        processName: String,
        ownerUser: String?,
        currentUser: String
    ) -> Bool {
        if pid <= 1 { return true }
        if processName.isEmpty || processName == "unknown" { return true }
        guard let ownerUser else { return true }
        if ownerUser == "root" || ownerUser.hasPrefix("_") { return true }
        if !currentUser.isEmpty && ownerUser != currentUser { return true }
        return false
    }
}

