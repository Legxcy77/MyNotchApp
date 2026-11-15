import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var reason: String
    public var body: Data

    public init(statusCode: Int, reason: String, json: String) {
        self.statusCode = statusCode
        self.reason = reason
        self.body = Data(json.utf8)
    }

    public func serialized() -> Data {
        let head = "HTTP/1.1 \(statusCode) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}

public enum HTTPParseResult: Equatable, Sendable {
    case incomplete
    case invalid
    case complete(HTTPRequest)
}

public enum HTTPRequestParser {
    private static let separator = Data("\r\n\r\n".utf8)
    private static let maxHeaderBytes = 16 * 1024
    private static let maxBodyBytes = 256 * 1024

    public static func parse(_ buffer: Data) -> HTTPParseResult {
        guard let sepRange = buffer.range(of: separator) else {
            return buffer.count > maxHeaderBytes ? .invalid : .incomplete
        }

        let headerData = buffer[..<sepRange.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return .invalid
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return .invalid }

        let method = String(parts[0]).uppercased()
        let rawTarget = String(parts[1])
        let path = rawTarget.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawTarget

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
        guard contentLength >= 0, contentLength <= maxBodyBytes else { return .invalid }

        let bodyStart = sepRange.upperBound
        let available = buffer.count - bodyStart
        guard available >= contentLength else { return .incomplete }

        let body = Data(buffer[bodyStart..<(bodyStart + contentLength)])
        return .complete(HTTPRequest(method: method, path: path, headers: headers, body: body))
    }
}

