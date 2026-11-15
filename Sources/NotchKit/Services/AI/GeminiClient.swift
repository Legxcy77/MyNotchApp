import Foundation

public enum GeminiKeychain {
    private static var keyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent("MyNotchApp", isDirectory: true)
            .appendingPathComponent("gemini-api-key", isDirectory: false)
    }

    public static func loadKey() -> String? {
        if let data = try? Data(contentsOf: keyFileURL),
           let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        return nil
    }

    public static func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dir = keyFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data(trimmed.utf8).write(to: keyFileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
    }
}

public enum GeminiError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case httpError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not set"
        case .httpError(let code, let body):
            return "Gemini HTTP \(code): \(body)"
        }
    }
}

public struct GeminiClient: Sendable {
    private struct SSEChunk: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                    let thought: Bool?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    public init() {}

    public static func extractDelta(fromSSELine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let jsonStr = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !jsonStr.isEmpty, jsonStr != "[DONE]" else { return nil }
        guard let data = jsonStr.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(SSEChunk.self, from: data) else { return nil }
        let text = chunk.candidates?.first?.content?.parts?
            .filter { $0.thought != true }
            .compactMap(\.text)
            .joined() ?? ""
        return text.isEmpty ? nil : text
    }

    public func streamResponse(
        prompt: String,
        apiKey: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws {
        try await streamChat(
            messages: [AIChatMessage(role: .user, text: prompt)],
            apiKey: apiKey,
            onDelta: onDelta
        )
    }

    public func streamChat(
        messages: [AIChatMessage],
        apiKey: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.missingAPIKey
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent?alt=sse&key=\(apiKey)") else {
            return
        }

        let contents: [[String: Any]] = messages
            .suffix(12)
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { msg in
                [
                    "role": msg.role.rawValue,
                    "parts": [["text": msg.text]]
                ]
            }

        let systemPrompt = """
        You are the built-in Quick AI chat assistant inside MyNotchApp, a personal macOS Dynamic Island / Notch developer cockpit built with Swift 6, SwiftUI, and AppKit.
        Match the user's language (Thai or English). Keep answers concise, crisp, and easy to read inside a compact notch chat bubble.
        MyNotchApp features & shortcuts:
        - ⌥Space: Command Palette (package.json / Makefile / Package.swift tasks)
        - ⌥⌘V: Smart Clipboard & History (JWT, JSON, Base64, URL, Unix timestamp, Hex, UUID)
        - ⌥A: Quick AI Chat (presets: TH ↔ EN, Explain Error, Explain Regex / Code)
        - Tabs: Overview (Agents, Dev Servers, Git, GitHub PR/CI, Meeting, System Pulse), Media (Spotify/Apple Music/Safari/Zen/Chrome + LRCLib lyrics), Tools (Area/Full Screenshot, Vision OCR TH/EN, Color Picker Hex, Text Transformer), Focus (Timer + Shortcuts), Camera (Mirror), Timeline (Run history).
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": 1024
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var errText = ""
            for try await line in bytes.lines {
                errText += line
                if errText.count > 200 { break }
            }
            throw GeminiError.httpError(http.statusCode, errText)
        }

        for try await line in bytes.lines {
            if Task.isCancelled { break }
            if let delta = Self.extractDelta(fromSSELine: line) {
                await onDelta(delta)
            }
        }
    }
}

