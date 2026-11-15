import Foundation

public struct LogLineMatcher: Sendable {
    public static let defaultPattern = "ERROR|Exception|FATAL"

    private let regex: NSRegularExpression?

    public init(pattern: String = LogLineMatcher.defaultPattern) {
        self.regex = try? NSRegularExpression(pattern: pattern)
    }

    public func matchingLines(in text: String) -> [String] {
        guard let regex else { return [] }
        return text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { line in
                let range = NSRange(line.startIndex..., in: line)
                return regex.firstMatch(in: line, range: range) != nil
            }
    }
}

