import SwiftUI

struct ToastView: View {
    let toast: Toast
    let clearance: CGFloat
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let path = toast.thumbnailPath, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                ZStack {
                    Circle().fill(toast.tint.color.opacity(0.18))
                    Image(systemName: toast.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(toast.tint.color)
                }
                .frame(width: 30, height: 30)
            }

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
                Image(systemName: toast.errorLog != nil ? "chevron.down" : "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
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

struct MeetingEarsView: View {
    let notchWidth: CGFloat
    let meeting: UpcomingMeeting

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 0) {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Toast.Tint.waiting.color)
                    .frame(width: IslandLayout.earWidth)

                Spacer()
                    .frame(width: max(0, notchWidth))

                Text(MeetingDetector.countdownText(until: meeting.startDate, now: context.date))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Toast.Tint.waiting.color)
                    .frame(width: IslandLayout.earWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ExpandedView: View {
    let clearance: CGFloat
    let expandedTab: ExpandedTab
    let sessions: [AgentSession]
    let servers: [DevServer]
    let stagedFiles: [URL]
    let gitStatus: GitStatus?
    let runHistory: [RunRecord]
    let nowPlaying: NowPlayingTrack?
    let lyrics: LRCDocument?
    let nextMeeting: UpcomingMeeting?
    let focusSession: FocusSession?
    let focusDurationMinutes: Int
    let systemPulse: [SystemPulseSample]
    let onSelectTab: (ExpandedTab) -> Void
    let onClearFinished: () -> Void
    let onClearRunHistory: () -> Void
    let onServerAction: (NotchStore.DevServerAction) -> Void
    let onMediaCommand: (MediaCommand) -> Void
    let onJoinMeeting: (URL) -> Void
    let onStartFocus: (Int) -> Void
    let onStopFocus: () -> Void
    let onSelectFocusMinutes: (Int) -> Void
    let onRemoveFile: (URL) -> Void
    let onClearFiles: () -> Void

    private var hasFinished: Bool {
        sessions.contains { !$0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.everyMinute) { context in
                HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ExpandedTabPill(
                            title: "Overview",
                            isSelected: expandedTab == .overview
                        ) {
                            onSelectTab(.overview)
                        }
                        ExpandedTabPill(
                            title: "Media",
                            isSelected: expandedTab == .media
                        ) {
                            onSelectTab(.media)
                        }
                        ExpandedTabPill(
                            title: "Focus",
                            isSelected: expandedTab == .focus
                        ) {
                            onSelectTab(.focus)
                        }
                        ExpandedTabPill(
                            title: "Mirror",
                            isSelected: expandedTab == .mirror
                        ) {
                            onSelectTab(.mirror)
                        }
                        ExpandedTabPill(
                            title: runHistory.isEmpty ? "Timeline" : "Timeline (\(runHistory.count))",
                            isSelected: expandedTab == .timeline
                        ) {
                            onSelectTab(.timeline)
                        }
                    }
                    if expandedTab == .overview && hasFinished {
                        Button("Clear", action: onClearFinished)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if expandedTab == .timeline && !runHistory.isEmpty {
                        Button("Clear", action: onClearRunHistory)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .foregroundStyle(.white)
            }

            if expandedTab == .media {
                MediaExpandedView(track: nowPlaying, lyrics: lyrics, onCommand: onMediaCommand)
            } else if expandedTab == .focus {
                FocusTabView(
                    session: focusSession,
                    selectedMinutes: focusDurationMinutes,
                    onSelectMinutes: onSelectFocusMinutes,
                    onStart: onStartFocus,
                    onStop: onStopFocus
                )
            } else if expandedTab == .mirror {
                CameraMirrorView()
            } else if expandedTab == .timeline {
                if runHistory.isEmpty {
                    Text("No completed commands or agent runs yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(runHistory) { record in
                                RunTimelineRow(record: record)
                            }
                        }
                    }
                }
            } else if sessions.isEmpty && servers.isEmpty && stagedFiles.isEmpty && gitStatus == nil && nextMeeting == nil && systemPulse.isEmpty {
                Text("All quiet. Builds, agents and servers will show up here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                if let latest = systemPulse.last {
                    SystemPulseRow(samples: systemPulse, latest: latest)
                }
                if let meeting = nextMeeting {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 8) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Toast.Tint.waiting.color)
                            Text(meeting.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(MeetingDetector.countdownText(until: meeting.startDate, now: context.date))
                                .font(.system(size: 11, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.55))
                            Button("Join") {
                                onJoinMeeting(meeting.joinURL)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Toast.Tint.waiting.color, in: Capsule())
                        }
                    }
                }
                if let git = gitStatus {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Toast.Tint.info.color)
                        Text(git.repoName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(git.branch)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                        if git.dirtyCount > 0 {
                            Text("\(git.dirtyCount) dirty")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Toast.Tint.waiting.color)
                        }
                        if git.ahead > 0 || git.behind > 0 {
                            Text("↑\(git.ahead) ↓\(git.behind)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer(minLength: 0)
                    }
                }
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

private struct SystemPulseRow: View {
    let samples: [SystemPulseSample]
    let latest: SystemPulseSample

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(latest.cpuPercent >= 80 ? Toast.Tint.failure.color : Toast.Tint.info.color)

            Text(String(format: "CPU %.0f%%", latest.cpuPercent))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))

            Text(String(format: "RAM %.1f/%.0fG", latest.ramUsedGB, latest.ramTotalGB))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geo in
                if samples.count >= 2 {
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        for (idx, s) in samples.enumerated() {
                            let x = w * CGFloat(idx) / CGFloat(samples.count - 1)
                            let y = h * (1 - CGFloat(min(100, max(0, s.cpuPercent))) / 100.0)
                            if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Toast.Tint.info.color.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 14)
        }
    }
}

private struct FocusTabView: View {
    let session: FocusSession?
    let selectedMinutes: Int
    let onSelectMinutes: (Int) -> Void
    let onStart: (Int) -> Void
    let onStop: () -> Void

    private let presets = [5, 15, 25, 45]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FOCUS TIMER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))

                    if let session {
                        Text(session.formattedRemaining(at: context.date))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    } else {
                        Text("\(selectedMinutes):00")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { mins in
                            Button("\(mins)m") {
                                onSelectMinutes(mins)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(selectedMinutes == mins ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(selectedMinutes == mins ? .white : .white.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer()

                if session != nil {
                    Button {
                        onStop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Toast.Tint.failure.color.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onStart(selectedMinutes)
                    } label: {
                        Label("Start Focus", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ExpandedTabPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? .white.opacity(0.16) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct RunTimelineRow: View {
    let record: RunRecord

    private var statusColor: Color {
        record.succeeded ? Toast.Tint.success.color : Toast.Tint.failure.color
    }

    private var cwdName: String? {
        guard let cwd = record.cwd, !cwd.isEmpty else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: record.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor)
            Image(systemName: record.kind == .command ? "terminal" : "cpu")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 12)
            Text(record.title)
                .font(.system(size: 11.5, weight: .medium, design: record.kind == .command ? .monospaced : .default))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
            if let cwdName {
                Text(cwdName)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(record.formattedDuration)
                .font(.system(size: 10.5, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
            Text("exit \(record.exitCode)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(statusColor.opacity(0.14), in: Capsule())
        }
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

            Text(":\(String(server.port))")
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

