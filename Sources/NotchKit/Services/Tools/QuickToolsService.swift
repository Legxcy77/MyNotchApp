import AppKit
import Foundation
import Vision

public enum TextTransformKind: String, CaseIterable, Sendable {
    case uppercase = "UPPER"
    case lowercase = "lower"
    case trimAndCollapse = "Clean"
    case prettyJSON = "JSON"
}

public enum TextTransformer {
    public struct Stats: Equatable, Sendable {
        public let characters: Int
        public let words: Int
        public let lines: Int
    }

    public static func stats(for text: String) -> Stats {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let lines = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count
        return Stats(characters: text.count, words: words, lines: lines)
    }

    public static func transform(_ text: String, _ kind: TextTransformKind) -> String {
        switch kind {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .trimAndCollapse:
            return text
                .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                .joined(separator: " ")
        case .prettyJSON:
            guard let data = text.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                  let str = String(data: pretty, encoding: .utf8) else {
                return text
            }
            return str
        }
    }
}

@MainActor
public enum QuickToolsService {
    public static func pickColor(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        NSColorSampler().show { selected in
            guard let color = selected?.usingColorSpace(.sRGB) else {
                Task { @MainActor in completion(nil) }
                return
            }
            let r = Int((color.redComponent * 255).rounded())
            let g = Int((color.greenComponent * 255).rounded())
            let b = Int((color.blueComponent * 255).rounded())
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            Task { @MainActor in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hex, forType: .string)
                completion(hex)
            }
        }
    }

    public static func captureScreenshot(interactive: Bool) {
        Task.detached(priority: .userInitiated) {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            let name = "Screenshot \(Int(Date().timeIntervalSince1970)).png"
            let path = desktop.appendingPathComponent(name).path
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = interactive ? ["-i", path] : ["-x", path]
            try? p.run()
        }
    }

    public static func ocrScreenRegion(completion: @escaping @MainActor (String?) -> Void) {
        Task.detached(priority: .userInitiated) {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mynotch-ocr-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: tmp) }

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-i", "-x", tmp.path]
            try? p.run()
            p.waitUntilExit()

            guard FileManager.default.fileExists(atPath: tmp.path),
                  let image = NSImage(contentsOf: tmp),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                await MainActor.run { completion(nil) }
                return
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["th-TH", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")

            await MainActor.run {
                guard !text.isEmpty else {
                    completion(nil)
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                completion(text)
            }
        }
    }
}

