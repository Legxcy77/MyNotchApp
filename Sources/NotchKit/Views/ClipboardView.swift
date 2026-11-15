import AppKit
import SwiftUI

struct ClipboardView: View {
    let history: ClipboardHistory
    let isPaused: Bool
    let clearance: CGFloat
    let onPaste: (ClipboardItem) -> Void
    let onCopyTransformed: (String) -> Void
    let onTogglePause: () -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private var results: [ClipboardItem] {
        history.filtered(by: query)
    }

    private var smartMatch: SmartClipboardMatch? {
        guard case .text(let latest) = history.items.first?.content else { return nil }
        return SmartClipboardDetector.detect(latest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                TextField("Search clipboard…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($searchFocused)
                    .onSubmit {
                        pasteSelected()
                    }

                Button(action: onTogglePause) {
                    HStack(spacing: 4) {
                        Image(systemName: isPaused ? "pause.circle.fill" : "record.circle")
                            .font(.system(size: 10))
                        Text(isPaused ? "Paused" : "Pause")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(isPaused ? Toast.Tint.waiting.color : .white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)

                Text("⌥⌘V")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let match = smartMatch {
                HStack(spacing: 8) {
                    if case .hexColor(_, let r, let g, let b, let a) = match {
                        Circle()
                            .fill(Color(red: r, green: g, blue: b, opacity: a))
                            .frame(width: 12, height: 12)
                    }
                    Text(match.badgeTitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Toast.Tint.info.color)
                    Text(match.summary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Button(match.actionLabel) {
                        onCopyTransformed(match.copyableResult)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Toast.Tint.info.color.opacity(0.28), in: Capsule())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            if results.isEmpty {
                Spacer()
                Text(history.items.isEmpty ? "Clipboard history is empty." : "No matches.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            ClipboardCard(item: item, isSelected: index == selectedIndex)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onPaste(item)
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, clearance + 12)
        .padding(.bottom, 14)
        .onAppear {
            selectedIndex = 0
            searchFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex + 1 < results.count { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private func pasteSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        onPaste(results[selectedIndex])
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch item.content {
            case .image(let data):
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Label(item.previewText, systemImage: "photo")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
            case .text:
                Text(item.previewText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Image(systemName: {
                    if case .image = item.content { return "photo" }
                    return "doc.on.clipboard"
                }())
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Text(item.copiedAt, format: .dateTime.hour().minute())
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(
            isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

