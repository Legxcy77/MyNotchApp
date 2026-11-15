import Foundation
import Security

public enum GeminiKeychain {
    private static let service = "com.pawalit.MyNotchApp"
    private static let account = "gemini-api-key"

    public static func loadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == true ? nil : key
    }

    public static func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var attrs = query
            attrs[kSecValueData as String] = data
            SecItemAdd(attrs as CFDictionary, nil)
        }
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
        let text = chunk.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
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
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=\(apiKey)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
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

