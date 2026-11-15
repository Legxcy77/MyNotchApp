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
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.missingAPIKey
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent?alt=sse&key=\(apiKey)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": "Reply concisely and directly for a compact macOS notch quick-assistant. Match the user's language."]]
            ],
            "contents": [["parts": [["text": prompt]]]],
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

