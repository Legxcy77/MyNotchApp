import Foundation

public struct EnvGuardReport: Equatable, Sendable {
    public var missingKeys: [String]
    public var extraKeys: [String]
    public var invalidLines: [String]
    public var checkedAt: Date

    public var isHealthy: Bool {
        missingKeys.isEmpty && invalidLines.isEmpty
    }

    public init(
        missingKeys: [String],
        extraKeys: [String],
        invalidLines: [String],
        checkedAt: Date = Date()
    ) {
        self.missingKeys = missingKeys
        self.extraKeys = extraKeys
        self.invalidLines = invalidLines
        self.checkedAt = checkedAt
    }
}

/// Compares `.env.example` and `.env` strictly by key names.
/// Never reads, stores, logs, or exposes secret values.
public enum EnvGuard {
    public static func compare(exampleContent: String, envContent: String, now: Date = Date()) -> EnvGuardReport {
        let exampleKeys = parseKeys(from: exampleContent).keys
        let envParsed = parseKeys(from: envContent)

        let missing = exampleKeys.subtracting(envParsed.keys).sorted()
        let extra = envParsed.keys.subtracting(exampleKeys).sorted()

        return EnvGuardReport(
            missingKeys: missing,
            extraKeys: extra,
            invalidLines: envParsed.invalidLineNumbers.map { "Line \($0)" },
            checkedAt: now
        )
    }

    private static func parseKeys(from content: String) -> (keys: Set<String>, invalidLineNumbers: [Int]) {
        var keys = Set<String>()
        var invalidLines: [Int] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let withoutExport = trimmed.hasPrefix("export ")
                ? String(trimmed.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
                : trimmed

            guard let eqIdx = withoutExport.firstIndex(of: "=") else {
                invalidLines.append(index + 1)
                continue
            }
            let key = String(withoutExport[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            if key.isEmpty || key.contains(" ") {
                invalidLines.append(index + 1)
            } else {
                keys.insert(key)
            }
        }
        return (keys, invalidLines)
    }
}

public struct SafeAPIHealthResult: Equatable, Sendable, Identifiable {
    public var id: String { url.absoluteString }
    public var url: URL
    public var statusCode: Int?
    public var latencyMs: Int?
    public var errorMessage: String?
    public var checkedAt: Date

    public var isHealthy: Bool {
        guard let statusCode else { return false }
        return (200..<300).contains(statusCode)
    }
}

public enum SafeAPIHealthCheck {
    /// Only allows safe read-only HTTP methods (`GET`, `HEAD`) for automated health checks.
    public static func isSafeMethod(_ method: String) -> Bool {
        let upper = method.uppercased()
        return upper == "GET" || upper == "HEAD"
    }
}

