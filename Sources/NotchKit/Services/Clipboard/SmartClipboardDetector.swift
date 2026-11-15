import Foundation

public enum SmartClipboardMatch: Equatable, Sendable {
    case jwt(header: String, payload: String)
    case json(pretty: String)
    case unixEpoch(seconds: TimeInterval, formatted: String)
    case hexColor(hex: String, r: Double, g: Double, b: Double, a: Double)
    case uuid(String)
    case urlEncoded(decoded: String)
    case base64(decoded: String)

    public var badgeTitle: String {
        switch self {
        case .jwt: "JWT"
        case .json: "JSON"
        case .unixEpoch: "Epoch"
        case .hexColor: "Color"
        case .uuid: "UUID"
        case .urlEncoded: "URL"
        case .base64: "Base64"
        }
    }

    public var summary: String {
        switch self {
        case .jwt(_, let payload):
            return payload.replacingOccurrences(of: "\n", with: " ")
        case .json(let pretty):
            return pretty.replacingOccurrences(of: "\n", with: " ")
        case .unixEpoch(_, let formatted):
            return formatted
        case .hexColor(let hex, let r, let g, let b, _):
            return "\(hex) · rgb(\(Int((r * 255).rounded())), \(Int((g * 255).rounded())), \(Int((b * 255).rounded())))"
        case .uuid(let u):
            return u
        case .urlEncoded(let decoded), .base64(let decoded):
            return decoded.replacingOccurrences(of: "\n", with: " ")
        }
    }

    public var actionLabel: String {
        switch self {
        case .jwt: "Copy Payload"
        case .json: "Pretty JSON"
        case .unixEpoch: "Copy Time"
        case .hexColor: "Copy RGB"
        case .uuid: "Copy Upper"
        case .urlEncoded, .base64: "Copy Decoded"
        }
    }

    public var copyableResult: String {
        switch self {
        case .jwt(let header, let payload):
            return "Header:\n\(header)\n\nPayload:\n\(payload)"
        case .json(let pretty):
            return pretty
        case .unixEpoch(_, let formatted):
            return formatted
        case .hexColor(_, let r, let g, let b, _):
            return "rgb(\(Int((r * 255).rounded())), \(Int((g * 255).rounded())), \(Int((b * 255).rounded())))"
        case .uuid(let u):
            return u
        case .urlEncoded(let decoded), .base64(let decoded):
            return decoded
        }
    }
}

public enum SmartClipboardDetector {
    public static func detect(_ raw: String, timeZone: TimeZone = .current) -> SmartClipboardMatch? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if let jwt = detectJWT(s) { return jwt }
        if let json = detectJSON(s) { return json }
        if let color = detectHexColor(s) { return color }
        if let uuid = detectUUID(s) { return uuid }
        if let epoch = detectUnixEpoch(s, timeZone: timeZone) { return epoch }
        if let url = detectURLEncoded(s) { return url }
        if let b64 = detectBase64(s) { return b64 }
        return nil
    }

    private static func detectJWT(_ s: String) -> SmartClipboardMatch? {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].hasPrefix("eyJ"),
              let headerData = decodeBase64URL(String(parts[0])),
              let payloadData = decodeBase64URL(String(parts[1])),
              let header = prettyJSON(from: headerData),
              let payload = prettyJSON(from: payloadData) else {
            return nil
        }
        return .jwt(header: header, payload: payload)
    }

    private static func detectJSON(_ s: String) -> SmartClipboardMatch? {
        guard (s.hasPrefix("{") && s.hasSuffix("}")) || (s.hasPrefix("[") && s.hasSuffix("]")),
              let data = s.data(using: .utf8),
              let pretty = prettyJSON(from: data) else {
            return nil
        }
        return .json(pretty: pretty)
    }

    private static func detectHexColor(_ s: String) -> SmartClipboardMatch? {
        let hex = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard s.hasPrefix("#"), [3, 6, 8].contains(hex.count),
              hex.allSatisfy(\.isHexDigit),
              let value = UInt64(hex, radix: 16) else {
            return nil
        }

        let r, g, b, a: Double
        switch hex.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15.0
            g = Double((value >> 4) & 0xF) / 15.0
            b = Double(value & 0xF) / 15.0
            a = 1.0
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        default:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }
        return .hexColor(hex: "#\(hex.uppercased())", r: r, g: g, b: b, a: a)
    }

    private static func detectUUID(_ s: String) -> SmartClipboardMatch? {
        guard s.count == 36, let parsed = UUID(uuidString: s) else { return nil }
        return .uuid(parsed.uuidString)
    }

    private static func detectUnixEpoch(_ s: String, timeZone: TimeZone) -> SmartClipboardMatch? {
        guard s.allSatisfy(\.isNumber), s.count == 10 || s.count == 13,
              let rawNum = Double(s) else {
            return nil
        }
        let seconds = s.count == 13 ? rawNum / 1000.0 : rawNum
        // 2000-01-01 .. 2100-01-01
        guard seconds >= 946_684_800 && seconds <= 4_102_444_800 else { return nil }

        let date = Date(timeIntervalSince1970: seconds)
        let fmt = DateFormatter()
        fmt.timeZone = timeZone
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        return .unixEpoch(seconds: seconds, formatted: fmt.string(from: date))
    }

    private static func detectURLEncoded(_ s: String) -> SmartClipboardMatch? {
        guard s.contains("%"),
              let decoded = s.removingPercentEncoding,
              decoded != s else {
            return nil
        }
        return .urlEncoded(decoded: decoded)
    }

    private static func detectBase64(_ s: String) -> SmartClipboardMatch? {
        guard s.count >= 8, s.count % 4 == 0,
              !s.contains(" "),
              let data = Data(base64Encoded: s),
              let decoded = String(data: data, encoding: .utf8),
              decoded != s,
              decoded.unicodeScalars.allSatisfy({ $0.value >= 0x20 || $0 == "\n" || $0 == "\t" }) else {
            return nil
        }
        return .base64(decoded: decoded)
    }

    private static func decodeBase64URL(_ part: String) -> Data? {
        var b64 = part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        return Data(base64Encoded: b64)
    }

    private static func prettyJSON(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(obj),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }
}
