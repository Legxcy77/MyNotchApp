import SwiftUI

struct ToastView: View {
    let toast: Toast
    let clearance: CGFloat
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(toast.tint.color.opacity(0.18))
                Image(systemName: toast.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(toast.tint.color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if let subtitle = toast.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 0)

            if onTap != nil {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, clearance)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

struct CollapsedEarsView: View {
    let notchWidth: CGFloat
    let workingCount: Int
    let waitingCount: Int

    private var activeCount: Int { workingCount + waitingCount }
    private var tint: Color {
        waitingCount > 0 ? Toast.Tint.waiting.color : Toast.Tint.info.color
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if waitingCount > 0 {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                }
            }
            .frame(width: IslandLayout.earWidth)

            Spacer()
                .frame(width: max(0, notchWidth))

            Text("\(activeCount)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: IslandLayout.earWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ExpandedView: View {
    let clearance: CGFloat
    let sessions: [AgentSession]
    let servers: [DevServer]
    let stagedFiles: [URL]
    let onClearFinished: () -> Void
    let onServerAction: (NotchStore.DevServerAction) -> Void
    let onRemoveFile: (URL) -> Void
    let onClearFiles: () -> Void

    private var hasFinished: Bool {
        sessions.contains { !$0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.everyMinute) { context in
                HStack(alignment: .firstTextBaseline) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    if hasFinished {
                        Button("Clear", action: onClearFinished)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .foregroundStyle(.white)
            }

            if sessions.isEmpty && servers.isEmpty && stagedFiles.isEmpty {
                Text("All quiet. Builds, agents and servers will show up here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                if !sessions.isEmpty {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(sessions.prefix(3)) { session in
                                AgentSessionRow(session: session, now: context.date)
                            }
                        }
                    }
                }

                if !servers.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(servers.prefix(3)) { server in
                            DevServerRow(server: server, onAction: onServerAction)
                        }
                    }
                }

                if !stagedFiles.isEmpty {
                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(stagedFiles, id: \.self) { url in
                                    StagedFileChip(url: url) {
                                        onRemoveFile(url)
                                    }
                                }
                            }
                        }
                        Button("Clear", action: onClearFiles)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, clearance + 12)
        .padding(.bottom, 14)
    }
}

private struct StagedFileChip: View {
    let url: URL
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 14, height: 14)
            Text(url.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: 110, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.1), in: Capsule())
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
    }
}

private struct DevServerRow: View {
    let server: DevServer
    let onAction: (NotchStore.DevServerAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Toast.Tint.success.color)
                .frame(width: 6, height: 6)

            Text(":\(server.port)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)

            Text(server.label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button { onAction(.open(server)) } label: {
                    Image(systemName: "arrow.up.forward")
                }
                Button { onAction(.copy(server)) } label: {
                    Image(systemName: "doc.on.doc")
                }
                Button { onAction(.kill(server)) } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(Toast.Tint.failure.color.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct AgentSessionRow: View {
    let session: AgentSession
    let now: Date

    private var tint: Color {
        switch session.state {
        case .working: Toast.Tint.info.color
        case .waiting: Toast.Tint.waiting.color
        case .done: Toast.Tint.success.color
        case .failed: Toast.Tint.failure.color
        }
    }

    private var elapsedText: String {
        let end = session.isActive ? now : session.updatedAt
        let s = max(0, Int(end.timeIntervalSince(session.startedAt)))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(session.source)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)

            if let dir = session.cwdBasename {
                Text(dir)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if let title = session.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Text(elapsedText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

