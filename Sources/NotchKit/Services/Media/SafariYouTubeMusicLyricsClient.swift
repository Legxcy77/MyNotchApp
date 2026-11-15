import AppKit
import Foundation
import os

public struct SafariYouTubeMusicLyricsClient: Sendable {
    private static let logger = Logger(subsystem: "com.pawalit.MyNotchApp", category: "SafariLyrics")

    public init() {}

    /// Reads visible lyrics from an open YouTube Music tab in Safari via Apple Events.
    /// Requires Safari -> Develop -> Allow JavaScript from Apple Events.
    public func fetchLyrics() async -> String? {
        let isSafariRunning = await MainActor.run {
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        }
        guard isSafariRunning else { return nil }

        return await Task.detached(priority: .utility) {
            Self.runAppleScript()
        }.value
    }

    public static func cleanExtractedLyrics(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }
        let joined = lines.joined(separator: "\n")
        guard joined.count >= 20 else { return nil }
        return joined
    }

    private static func runAppleScript() -> String? {
        let js = """
        (function() {
            var desc = document.querySelector('ytmusic-tab-renderer ytmusic-description-shelf-renderer yt-formatted-string.description, ytmusic-description-shelf-renderer yt-formatted-string.description');
            if (desc && desc.innerText && desc.innerText.trim().length > 20) {
                return desc.innerText.trim();
            }
            var timed = Array.from(document.querySelectorAll('ytmusic-timed-lyrics-renderer .lyrics-line, yt-lyrics-line-renderer'))
                .map(function(el) { return (el.innerText || '').trim(); })
                .filter(Boolean);
            if (timed.length > 0) {
                return timed.join('\\n');
            }
            return '';
        })();
        """

        let escapedJS = js
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        let script = """
        tell application "Safari"
            if not running then return ""
            repeat with w in windows
                try
                    set t to current tab of w
                    if (URL of t) starts with "https://music.youtube.com" then
                        return do JavaScript "\(escapedJS)" in t
                    end if
                end try
            end repeat
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        if (URL of t) starts with "https://music.youtube.com" then
                            return do JavaScript "\(escapedJS)" in t
                        end if
                    end try
                end repeat
            end repeat
            return ""
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.debug("osascript failed to launch: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !errMsg.isEmpty {
                logger.debug("Safari lyrics AppleScript error: \(errMsg, privacy: .public)")
            }
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        return cleanExtractedLyrics(output)
    }
}

