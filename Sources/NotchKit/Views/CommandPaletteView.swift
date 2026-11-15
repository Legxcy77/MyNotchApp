import SwiftUI

struct CommandPaletteView: View {
    let tasks: [RepoTask]
    let repoName: String?
    let clearance: CGFloat
    let onRun: (RepoTask) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private var filtered: [RepoTask] {
        RepoTaskScanner.filter(tasks, query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Toast.Tint.info.color)

                TextField("Run task\(repoName.map { " in \($0)" } ?? "")…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($searchFocused)
                    .onSubmit {
                        runSelected()
                    }

                Text("⌥Space")
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

            if filtered.isEmpty {
                Spacer()
                Text(tasks.isEmpty ? "No package.json, Makefile, .csproj, or Package.swift found." : "No matching tasks.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, task in
                            HStack(spacing: 10) {
                                Text(task.kind.rawValue)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Toast.Tint.info.color)
                                    .frame(width: 44, alignment: .leading)

                                Text(task.command)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(index == selectedIndex ? 1.0 : 0.8))
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(task.detail)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(.white.opacity(index == selectedIndex ? 0.14 : 0))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onRun(task)
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
            if selectedIndex + 1 < filtered.count { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private func runSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        onRun(filtered[selectedIndex])
    }
}

