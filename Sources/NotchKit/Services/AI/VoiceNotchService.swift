import AppKit
@preconcurrency import AVFoundation
import Foundation
import Observation
@preconcurrency import Speech
import Vision

public enum VoiceNotchPhase: Equatable, Sendable {
    case idle
    case listening(partial: String)
    case thinking(query: String)
    case answered(reply: String)
    case failed(message: String)
}

public enum VoiceCommandPromptBuilder {
    public static func build(transcript: String, screenContext: String?) -> String {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let screenContext else {
            return cleanTranscript
        }
        let cleanContext = screenContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContext.isEmpty else {
            return cleanTranscript
        }
        let capped = String(cleanContext.prefix(2000))
        return """
        User voice request: \(cleanTranscript)

        Screen context (OCR):
        \(capped)
        """
    }
}

@MainActor
@Observable
public final class VoiceNotchService {
    public private(set) var phase: VoiceNotchPhase = .idle

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let gemini = GeminiClient()
    private var latestTranscript = ""

    public init() {}

    public func toggleListening(onAnswer: @escaping @MainActor (String, String) -> Void) {
        switch phase {
        case .listening:
            finishListeningAndQuery(onAnswer: onAnswer)
        case .idle, .answered, .failed:
            startListening(onAnswer: onAnswer)
        case .thinking:
            cancel()
        }
    }

    public func cancel() {
        stopAudioEngine()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        phase = .idle
    }

    public func startListening(onAnswer: @escaping @MainActor (String, String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized else {
                    self.phase = .failed(message: "กรุณาอนุญาต Speech Recognition ใน System Settings")
                    return
                }
                self.beginAudioCapture(onAnswer: onAnswer)
            }
        }
    }

    private func beginAudioCapture(onAnswer: @escaping @MainActor (String, String) -> Void) {
        stopAudioEngine()
        latestTranscript = ""
        phase = .listening(partial: "กำลังฟัง...")

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            phase = .failed(message: "Speech Recognizer ไม่พร้อมใช้งาน")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            phase = .failed(message: "เปิดไมโครโฟนไม่สำเร็จ: \(error.localizedDescription)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.latestTranscript = text
                    self.phase = .listening(partial: text.isEmpty ? "กำลังฟัง..." : text)
                    if result.isFinal {
                        self.finishListeningAndQuery(onAnswer: onAnswer)
                    }
                } else if let error {
                    if self.latestTranscript.isEmpty {
                        self.stopAudioEngine()
                        self.phase = .failed(message: error.localizedDescription)
                    } else {
                        self.finishListeningAndQuery(onAnswer: onAnswer)
                    }
                }
            }
        }
    }

    public func finishListeningAndQuery(onAnswer: @escaping @MainActor (String, String) -> Void) {
        stopAudioEngine()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        let query = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            phase = .idle
            return
        }

        phase = .thinking(query: query)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let screenText = await Self.captureActiveScreenOCRText()
            let prompt = VoiceCommandPromptBuilder.build(transcript: query, screenContext: screenText)
            do {
                guard let apiKey = GeminiKeychain.loadKey(), !apiKey.isEmpty else {
                    self.phase = .failed(message: "ยังไม่ได้ตั้ง Gemini API Key ใน Quick AI")
                    return
                }
                actor Buffer {
                    var text = ""
                    func append(_ s: String) { text += s }
                }
                let buffer = Buffer()
                try await self.gemini.streamResponse(prompt: prompt, apiKey: apiKey) { chunk in
                    await buffer.append(chunk)
                }
                let finalReply = await buffer.text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.phase = .answered(reply: finalReply)
                onAnswer(query, finalReply)
            } catch {
                self.phase = .failed(message: error.localizedDescription)
            }
        }
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    private static func captureActiveScreenOCRText() async -> String? {
        await Task.detached(priority: .utility) {
            guard CGPreflightScreenCaptureAccess(),
                  let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
                return nil
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.prefix(35).joined(separator: "\n")
            return joined.isEmpty ? nil : joined
        }.value
    }
}
