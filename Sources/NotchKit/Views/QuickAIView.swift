import AppKit
import SwiftUI

struct QuickAIView: View {
    let clearance: CGFloat
    let prompt: String
    let messages: [AIChatMessage]
    let isLoading: Bool
    let latestClipboardText: String?
    let onPromptChange: (String) -> Void
    let onSubmit: (String) -> Void
    let onClearChat: () -> Void
    let onClose: () -> Void

    @State private var hasKey = GeminiKeychain.loadKey() != nil
    @State private var apiKeyInput = ""
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasKey {
                keySetupView
            } else {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Toast.Tint.info.color)
                    Text("Gemini Chat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.8))
                    }

                    Spacer()

                    if !messages.isEmpty {
                        Button("New Chat") {
                            onClearChat()
                            isPromptFocused = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.08), in: Capsule())
                    }

                    Button("Esc") {
                        onClose()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }

                // Chat Thread Bento Container
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        if messages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ask anything or run a quick action on your clipboard:")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.45))
                                HStack(spacing: 6) {
                                    presetButton("TH ↔ EN") {
                                        let clip = latestClipboardText ?? prompt
                                        guard !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                        onSubmit("Translate naturally between Thai and English:\n\n\(clip)")
                                    }
                                    presetButton("Explain Error") {
                                        let clip = latestClipboardText ?? prompt
                                        guard !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                        onSubmit("Explain this error concisely and how to fix it:\n\n\(clip)")
                                    }
                                    presetButton("Explain Code") {
                                        let clip = latestClipboardText ?? prompt
                                        guard !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                        onSubmit("Explain what this regex or code snippet does concisely:\n\n\(clip)")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(messages) { msg in
                                    chatBubble(msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: messages.last?.text) { _, _ in
                        if let lastID = messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastID = messages.last?.id {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                // Bottom Input Bento Bar
                HStack(spacing: 8) {
                    TextField("Message Gemini…", text: Binding(
                        get: { prompt },
                        set: { onPromptChange($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white)
                    .focused($isPromptFocused)
                    .onSubmit {
                        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSubmit(trimmed)
                    }

                    Button {
                        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSubmit(trimmed)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .white.opacity(0.25)
                                    : Toast.Tint.info.color
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, clearance + 10)
        .padding(.bottom, 12)
        .onAppear {
            hasKey = GeminiKeychain.loadKey() != nil
            isPromptFocused = true
        }
        .onExitCommand(perform: onClose)
    }

    @ViewBuilder
    private func chatBubble(_ msg: AIChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 4) {
                if msg.role == .model && msg.text.isEmpty && isLoading {
                    Text("Thinking…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(msg.text)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.92))
                        .textSelection(.enabled)
                }

                if msg.role == .model && !msg.text.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.text, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                msg.role == .user
                    ? Toast.Tint.info.color.opacity(0.26)
                    : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            if msg.role == .model { Spacer(minLength: 36) }
        }
    }

    private var keySetupView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(Toast.Tint.waiting.color)
                Text("Enter Gemini API Key (saved locally)")
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

