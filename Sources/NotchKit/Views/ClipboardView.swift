import SwiftUI

struct ClipboardView: View {
    let history: ClipboardHistory
    let clearance: CGFloat
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private var results: [ClipboardItem] {
        history.filtered(by: query)
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

            if results.isEmpty {
                Spacer()
                Text(history.items.isEmpty ? "Clipboard history is empty." : "No matches.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            ClipboardRow(item: item, isSelected: index == selectedIndex)
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

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            switch item.content {
            case .text:
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 20, height: 20)
            case .image(let data):
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }

            Text(item.previewText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.78))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            Text(item.copiedAt, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.14 : 0))
        )
    }
}
