import Foundation

public struct TerminalParsedEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case serverReady(port: Int, url: String?)
        case error(category: String, summary: String, location: BuildSourceLocation?)
        case neutral
    }

    public var kind: Kind
    public var toolchain: DeveloperToolchain
}

/// Deterministic parser for common dev server and terminal outputs across Node/TS, .NET, and Swift.
public enum TerminalOutputParser {
    public static func parse(command: String, output: String, exitCode: Int32?) -> TerminalParsedEvent {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let toolchain = detectToolchain(command: command, output: trimmed)

        // 1. Port-in-use (Node EADDRINUSE / Swift / .NET)
        if let port = extractPortInUse(from: trimmed) {
            return TerminalParsedEvent(
                kind: .error(
                    category: "Port In Use",
                    summary: "Port \(port) ถูกใช้งานอยู่แล้ว (EADDRINUSE)",
                    location: nil
                ),
                toolchain: toolchain
            )
        }

        // 2. Missing Module (Node / Vite / Next.js)
        if let missingModule = firstCapture(
            pattern: #"Cannot find module\s+['"]([^'"]+)['"]"#,
            in: trimmed
        ) {
            return TerminalParsedEvent(
                kind: .error(
                    category: "Missing Module",
                    summary: "ไม่พบโมดูล '\(missingModule)'",
                    location: nil
                ),
                toolchain: toolchain
            )
        }

        // 3. Server Ready / Listening URL + Port (Vite, Next, Astro, Express, .NET, Swift)
        if exitCode == nil || exitCode == 0 {
            if let (port, url) = extractListeningServer(from: trimmed) {
                return TerminalParsedEvent(
                    kind: .serverReady(port: port, url: url),
                    toolchain: toolchain
                )
            }
        }

        // 4. Language-specific compiler / test errors via BuildOutputParser
        if let exitCode, exitCode != 0 {
            let parsedBuild = BuildOutputParser.parse(
                output: trimmed,
                toolchain: toolchain,
                kind: command.localizedCaseInsensitiveContains("test") ? .test : .build,
                exitCode: exitCode
            )
            if parsedBuild.errorCount > 0 || parsedBuild.failedTestCount > 0 || parsedBuild.primaryLocation != nil {
                return TerminalParsedEvent(
                    kind: .error(
                        category: "\(toolchain.displayName) Error",
                        summary: parsedBuild.summary,
                        location: parsedBuild.primaryLocation
                    ),
                    toolchain: toolchain
                )
            }

            // Generic runtime exception (TypeError, ReferenceError, Unhandled exception, Fatal error)
            let lines = trimmed.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
            if let runtimeLine = lines.first(where: {
                $0.contains("TypeError:") ||
                $0.contains("SyntaxError:") ||
                $0.contains("ReferenceError:") ||
                $0.contains("Unhandled exception") ||
                $0.contains("Fatal error:") ||
                $0.localizedCaseInsensitiveContains("error:")
            }) {
                return TerminalParsedEvent(
                    kind: .error(
                        category: "Runtime Error",
                        summary: String(runtimeLine.prefix(160)),
                        location: nil
                    ),
                    toolchain: toolchain
                )
            }

            return TerminalParsedEvent(
                kind: .error(
                    category: "Command Failed",
                    summary: "คำสั่งจบด้วย exit \(exitCode)",
                    location: nil
                ),
                toolchain: toolchain
            )
        }

        return TerminalParsedEvent(kind: .neutral, toolchain: toolchain)
    }

    private static func detectToolchain(command: String, output: String) -> DeveloperToolchain {
        let lower = command.lowercased()
        if lower.contains("swift") || output.contains(".swift:") { return .swift }
        if lower.contains("dotnet") || output.contains("Microsoft.Hosting.Lifetime") || output.contains(".cs(") { return .dotnet }
        if lower.contains("npm") || lower.contains("pnpm") || lower.contains("yarn") ||
            lower.contains("bun") || lower.contains("vite") || lower.contains("next") ||
            output.contains("VITE") || output.contains("TS") {
            return .nodeTypeScript
        }
        return .generic
    }

    private static func extractPortInUse(from text: String) -> Int? {
        if let portStr = firstCapture(pattern: #"EADDRINUSE[^\n]*?(?::::|:)(\d{2,5})"#, in: text) ??
            firstCapture(pattern: #"address already in use[^\n]*?:(\d{2,5})"#, in: text) {
            return Int(portStr)
        }
        return nil
    }

    private static func extractListeningServer(from text: String) -> (Int, String?)? {
        // Vite: Local:   http://localhost:5173/
        // .NET: Now listening on: https://localhost:7001
        // Next/Express/Generic: http://127.0.0.1:3000 or http://localhost:3000
        let urlRegex = try? NSRegularExpression(pattern: #"(?:Local:\s+|Now listening on:\s+|Listening on\s+|started server on\s+[^\n]*?)(https?://[^\s]+)"#)
        if let urlRegex {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = urlRegex.firstMatch(in: text, range: range),
               let urlRange = Range(match.range(at: 1), in: text) {
                let url = String(text[urlRange])
                if let portStr = firstCapture(pattern: #":(\d{2,5})"#, in: url), let port = Int(portStr) {
                    return (port, url)
                }
            }
        }
        if let portStr = firstCapture(pattern: #"(?:listening on port|started on port|port)\s+(\d{2,5})"#, in: text.lowercased()),
           let port = Int(portStr) {
            return (port, "http://localhost:\(port)")
        }
        return nil
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[r])
    }
}

/// Redacts secrets, tokens, and credentials before sending error snippets to external LLMs.
public enum ErrorRedactor {
    public static func redact(_ text: String) -> String {
        var result = text
        let patterns = [
            (#"(Bearer\s+)[A-Za-z0-9\-._~+/]+=*"#, "$1[REDACTED]"),
            (#"AIza[0-9A-Za-z\-_]{10,}"#, "[REDACTED]"),
            (#"sk-[A-Za-z0-9\-_]{10,}"#, "[REDACTED]"),
            (#"gh[pousr]_[A-Za-z0-9]{10,}"#, "[REDACTED]"),
            (#"(://[^:\s]+:)[^@\s]+(@)"#, "$1[REDACTED]$2"),
            (#"((?:API_KEY|SECRET|PASSWORD|TOKEN)\s*=\s*)[^\s\n]+"#, "$1[REDACTED]")
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        return result
    }
}

