import AppKit
import SwiftUI

struct QuickAIView: View {
    let clearance: CGFloat
    let prompt: String
    let response: String
    let isLoading: Bool
    let latestClipboardText: String?
    let onPromptChange: (String) -> Void
    let onSubmit: (String) -> Void
    let onClose: () -> Void

    @State private var hasKey = GeminiKeychain.loadKey() != nil
    @State private var apiKeyInput = ""
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasKey {
                keySetupView
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Toast.Tint.info.color)

                    TextField("Ask Gemini anything…", text: Binding(
                        get: { prompt },
                        set: { onPromptChange($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($isPromptFocused)
                    .onSubmit {
                        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSubmit(trimmed)
                    }

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Button("Esc") {
                        onClose()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }

                HStack(spacing: 6) {
                    presetButton("TH ↔ EN") {
                        let clip = latestClipboardText ?? prompt
                        onSubmit("Translate naturally between Thai and English:\n\n\(clip)")
                    }
                    presetButton("Explain Error") {
                        let clip = latestClipboardText ?? prompt
                        onSubmit("Explain this error concisely and how to fix it:\n\n\(clip)")
                    }
                    presetButton("Explain Regex / Code") {
                        let clip = latestClipboardText ?? prompt
                        onSubmit("Explain what this regex or code snippet does concisely:\n\n\(clip)")
                    }
                    Spacer()
                    if !response.isEmpty {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(response, forType: .string)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Toast.Tint.info.color)
                    }
                }

                ScrollView(.vertical, showsIndicators: true) {
                    Text(response.isEmpty ? "Pick a preset or type a prompt and press Enter." : response)
                        .font(.system(size: 12))
                        .foregroundStyle(response.isEmpty ? .white.opacity(0.4) : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, clearance + 10)
        .padding(.bottom, 14)
        .onAppear {
            hasKey = GeminiKeychain.loadKey() != nil
            isPromptFocused = true
        }
        .onExitCommand(perform: onClose)
    }

    private var keySetupView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(Toast.Tint.waiting.color)
                Text("Enter Gemini API Key (stored in macOS Keychain)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Button("Esc", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 8) {
                SecureField("AIza...", text: $apiKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Button("Save") {
                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    GeminiKeychain.saveKey(trimmed)
                    apiKeyInput = ""
                    hasKey = true
                    isPromptFocused = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(.white.opacity(0.1), in: Capsule())
    }
}
