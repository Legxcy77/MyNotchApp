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
            } else if toast.key == "preview:airpods" || toast.key?.hasPrefix("bluetooth:battery:") == true {
                SpatialDevice3DView(kind: .airPods)
                    .frame(width: 36, height: 36)
            } else if toast.key == "power:magsafe" {
                SpatialDevice3DView(kind: .magSafe(percent: 100, watts: nil))
                    .frame(width: 36, height: 36)
            } else {
                ZStack {
                    Circle().fill(toast.tint.color.opacity(0.18))
                    Image(systemName: toast.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(toast.tint.color)
                }
                .frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(toast.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    if let progress = toast.progress {
                        Spacer(minLength: 4)
                        Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                if let progress = toast.progress {
                    GeometryReader { geo in
                        let clamped = min(1, max(0, progress))
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule().fill(toast.tint.color.opacity(0.92))
                                .frame(width: max(4, geo.size.width * clamped))
                                .animation(.spring(response: 0.24, dampingFraction: 0.85), value: clamped)
                        }
                    }
                    .frame(height: 4)
                } else if let subtitle = toast.subtitle {
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

struct FaceScanEarsView: View {
    let notchWidth: CGFloat
    let status: FaceScanEarStatus

    var body: some View {
        HStack(spacing: 0) {
            // Left ear: Face ID icon + animated progress ring
            HStack(spacing: 6) {
                ZStack {
                    FaceScanSpinnerRing(
                        isVerifying: !status.isVerified,
                        isVerified: status.isVerified,
                        isAwaitingBlink: status.isAwaitingBlink,
                        lineWidth: 1.8
                    )
                    .frame(width: 20, height: 20)

                    Image(systemName: status.isVerified ? "checkmark" : "faceid")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(status.isVerified ? Color.green : Color.white)
                }
                Text("Face ID")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(width: IslandLayout.faceEarWidth)

            Spacer()
                .frame(width: max(0, notchWidth))

            // Right ear: live instruction
            Text(status.instruction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.isVerified ? Color.green : (status.isAwaitingBlink ? Color.orange : Color.white.opacity(0.9)))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: IslandLayout.faceEarWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    var dockerContainers: [DockerContainer] = []
    let stagedFiles: [URL]
    let gitStatus: GitStatus?
    let runHistory: [RunRecord]
    let nowPlaying: NowPlayingTrack?
    let lyrics: LRCDocument?
    let nextMeeting: UpcomingMeeting?
    let focusSession: FocusSession?
    let focusDurationMinutes: Int
    let systemPulse: [SystemPulseSample]
    let audioState: AudioStateSnapshot
    let notesPayload: NotesAndTasksPayload
    let androidDrop: AndroidDropStatus
    let latestClipboardText: String?
    var latestBuildResult: BuildTestResult? = nil
    var agentConflicts: [AgentConflict] = []
    var worklogEntries: [WorklogEntry] = []
    var worklogRange: WorklogRange = .today
    let onSelectTab: (ExpandedTab) -> Void
    let onClearFinished: () -> Void
    let onClearRunHistory: () -> Void
    let onServerAction: (NotchStore.DevServerAction) -> Void
    let onMediaCommand: (MediaCommand) -> Void
    let onAudioAction: (NotchStore.AudioAction) -> Void
    var onAdjustLyricsOffset: (TimeInterval) -> Void = { _ in }
    var onAirDropFiles: () -> Void = {}
    var onDockerAction: (DockerAction) -> Void = { _ in }
    var onBuildAction: (NotchStore.BuildAction) -> Void = { _ in }
    var onSelectWorklogRange: (WorklogRange) -> Void = { _ in }
    var onClearWorklog: () -> Void = {}
    let onQuickTool: (NotchStore.QuickToolAction) -> Void
    let onJoinMeeting: (URL) -> Void
    let onStartFocus: (Int) -> Void
    let onStopFocus: () -> Void
    let onSelectFocusMinutes: (Int) -> Void
    let onUpdateNote: (String) -> Void
    let onAddTask: (String) -> Void
    let onToggleTask: (UUID) -> Void
    let onRemoveTask: (UUID) -> Void
    let onToggleAndroidDrop: () -> Void
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
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        ExpandedTabPill(symbol: "house.fill", title: nil, isSelected: expandedTab == .overview) {
                            onSelectTab(.overview)
                        }
                        ExpandedTabPill(symbol: "music.note", title: nil, isSelected: expandedTab == .media) {
                            onSelectTab(.media)
                        }
                        ExpandedTabPill(symbol: "wrench.and.screwdriver.fill", title: nil, isSelected: expandedTab == .tools) {
                            onSelectTab(.tools)
                        }
                        ExpandedTabPill(symbol: "iphone.and.arrow.forward", title: nil, isSelected: expandedTab == .drop) {
                            onSelectTab(.drop)
                        }
                        ExpandedTabPill(symbol: "clock.arrow.circlepath", title: worklogEntries.isEmpty ? nil : "\(worklogEntries.count)", isSelected: expandedTab == .timeline) {
                            onSelectTab(.timeline)
                        }
                    }
                    .padding(3)
                    .background(.white.opacity(0.06), in: Capsule())

                    if expandedTab == .overview && hasFinished {
                        Button("Clear", action: onClearFinished)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    } else if expandedTab == .timeline && !worklogEntries.isEmpty {
                        Button("Clear", action: onClearWorklog)
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .foregroundStyle(.white)
            }

            if expandedTab == .media {
                MediaExpandedView(
                    track: nowPlaying,
                    lyrics: lyrics,
                    audioState: audioState,
                    onCommand: onMediaCommand,
                    onAudioAction: onAudioAction,
                    onAdjustLyricsOffset: onAdjustLyricsOffset
                )
            } else if expandedTab == .tools {
                ToolsTabView(latestClipboardText: latestClipboardText, onAction: onQuickTool)
            } else if expandedTab == .drop {
                AndroidDropTabView(
                    status: androidDrop,
                    stagedFiles: stagedFiles,
                    onToggleServer: onToggleAndroidDrop,
                    onClearFiles: onClearFiles,
                    onAirDropFiles: onAirDropFiles
                )
            } else if expandedTab == .timeline {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(WorklogRange.quickPresets, id: \.self) { range in
                            Button {
                                onSelectWorklogRange(range)
                            } label: {
                                Text(range.label)
                                    .font(.system(size: 10, weight: worklogRange == range ? .semibold : .medium))
                                    .foregroundStyle(.white.opacity(worklogRange == range ? 0.95 : 0.55))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        worklogRange == range ? .white.opacity(0.14) : .white.opacity(0.05),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    if worklogEntries.isEmpty {
                        bentoBox {
                            Text("ยังไม่มี worklog ในช่วง \(worklogRange.label)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    } else {
                        bentoBox {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(worklogEntries) { entry in
                                        WorklogEntryRow(
                                            entry: entry,
                                            showDate: worklogRange != .today && worklogRange != .yesterday
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                overviewBento
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, clearance + 10)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: expandedTab)
    }

    @ViewBuilder
    private var overviewBento: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // Left Bento Card: Now Playing or Live Workspace Status
                bentoBox {
                    if let track = nowPlaying, !track.title.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                if let artData = track.artworkData, let img = NSImage(data: artData) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.95))
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 18) {
                                Button { onMediaCommand(.previous) } label: {
                                    Image(systemName: "backward.fill").font(.system(size: 12))
                                }.buttonStyle(.plain)
                                Button { onMediaCommand(.togglePlayPause) } label: {
                                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 14))
                                }.buttonStyle(.plain)
                                Button { onMediaCommand(.next) } label: {
                                    Image(systemName: "forward.fill").font(.system(size: 12))
                                }.buttonStyle(.plain)
                                Spacer()
                                Button("Lyrics") { onSelectTab(.media) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            if let latest = systemPulse.last {
                                SystemPulseRow(samples: systemPulse, latest: latest)
                            }
                            if let git = gitStatus {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(Toast.Tint.info.color)
                                    Text(git.repoName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                    Text(git.branch)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                    if git.dirtyCount > 0 {
                                        Text("\(git.dirtyCount)M")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Toast.Tint.waiting.color)
                                    }
                                }
                            }
                            if let meeting = nextMeeting {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    HStack(spacing: 6) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Toast.Tint.waiting.color)
                                        Text(meeting.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        Text(MeetingDetector.countdownText(until: meeting.startDate, now: context.date))
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.6))
                                        Button("Join") { onJoinMeeting(meeting.joinURL) }
                                            .buttonStyle(.plain)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Toast.Tint.waiting.color, in: Capsule())
                                    }
                                }
                            }
                            if systemPulse.isEmpty && gitStatus == nil && nextMeeting == nil {
                                HStack(spacing: 6) {
                                    Circle().fill(Toast.Tint.success.color).frame(width: 7, height: 7)
                                    Text("All quiet · Ready")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)

                // Right Bento Card: 2x2 Quick Launch Grid
                bentoBox {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            quickTile("sparkles", "Ask AI") { onQuickTool(.openQuickAI) }
                            quickTile("terminal", "Palette") { onQuickTool(.openCommandPalette) }
                        }
                        HStack(spacing: 6) {
                            quickTile("doc.on.clipboard", "Clipboard") { onQuickTool(.openClipboard) }
                            quickTile("text.viewfinder", "Screen OCR") { onQuickTool(.ocr) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 88)
            }

            if let build = latestBuildResult {
                BuildResultBentoCard(result: build, onAction: onBuildAction)
            }

            if !agentConflicts.isEmpty {
                bentoBox {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(agentConflicts.prefix(2)) { conflict in
                            HStack(spacing: 6) {
                                Image(systemName: conflict.confidence == .confirmed ? "exclamationmark.2" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Toast.Tint.waiting.color)
                                Text(conflict.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(conflict.detail)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if !sessions.isEmpty || !servers.isEmpty || !dockerContainers.isEmpty || !stagedFiles.isEmpty {
                bentoBox {
                    VStack(alignment: .leading, spacing: 5) {
                        if !sessions.isEmpty {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                ForEach(sessions.prefix(2)) { session in
                                    AgentSessionRow(session: session, now: context.date)
                                }
                            }
                        }
                        if !servers.isEmpty {
                            ForEach(servers.prefix(2)) { server in
                                DevServerRow(server: server, onAction: onServerAction)
                            }
                        }
                        if !dockerContainers.isEmpty {
                            ForEach(dockerContainers.prefix(2)) { container in
                                DockerContainerRow(container: container, onAction: onDockerAction)
                            }
                        }
                        if !stagedFiles.isEmpty {
                            HStack(spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(stagedFiles, id: \.self) { url in
                                            StagedFileChip(url: url) { onRemoveFile(url) }
                                        }
                                    }
                                }
                                Button(action: onAirDropFiles) {
                                    Label("AirDrop", systemImage: "wave.3.up.circle.fill")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(Toast.Tint.info.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Toast.Tint.info.color.opacity(0.16), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                Button("Clear", action: onClearFiles)
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
    }

    private func bentoBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private struct DockerContainerRow: View {
        let container: DockerContainer
        let onAction: (DockerAction) -> Void

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Toast.Tint.info.color)
                Text(container.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !container.portsSummary.isEmpty {
                    Text(container.portsSummary)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button("Logs") { onAction(.pinLogs(container)) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Button("Restart") { onAction(.restart(container)) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Toast.Tint.waiting.color)
            }
        }
    }

    private func quickTile(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 31)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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

private struct ToolsTabView: View {
    let latestClipboardText: String?
    let onAction: (NotchStore.QuickToolAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Bento Box: Capture & Inspect (2x2)
            VStack(alignment: .leading, spacing: 6) {
                Text("CAPTURE")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 6) {
                    toolTile("rectangle.dashed", "Area Shot") { onAction(.screenshotArea) }
                    toolTile("macwindow", "Full Shot") { onAction(.screenshotFull) }
                }
                HStack(spacing: 6) {
                    toolTile("text.viewfinder", "Screen OCR") { onAction(.ocr) }
                    toolTile("eyedropper", "Color Pick") { onAction(.colorPicker) }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Right Bento Box: Quick Actions & Text Tools
            VStack(alignment: .leading, spacing: 6) {
                Text("ACTIONS & TEXT")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 6) {
                    toolTile("sparkles", "AI Chat") { onAction(.openQuickAI) }
                    toolTile("terminal", "Palette") { onAction(.openCommandPalette) }
                    toolTile("doc.on.clipboard", "Clips") { onAction(.openClipboard) }
                }
                HStack(spacing: 6) {
                    toolTile("lock.fill", "Lock") { onAction(.lockScreen) }
                    toolTile("lock.rotation", "Auto-Lock") { onAction(.toggleAutoLock) }
                    toolTile("faceid", "Face ID") { onAction(.setupFaceUnlock) }
                }

                if let text = latestClipboardText, !text.isEmpty {
                    let stats = TextTransformer.stats(for: text)
                    HStack(spacing: 4) {
                        Text("\(stats.words)w·\(stats.characters)c")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer(minLength: 0)
                        ForEach(TextTransformKind.allCases, id: \.self) { kind in
                            Button(kind.rawValue) {
                                onAction(.transformClipboard(kind))
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                } else {
                    Text("Copy text to transform (UPPER / lower / Clean / JSON)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func toolTile(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ExpandedTabPill: View {
    let symbol: String
    let title: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, title == nil ? 7 : 9)
            .padding(.vertical, 4)
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

            Text(server.associatedProject ?? server.label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)

            Text("PID \(server.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button { onAction(.open(server)) } label: {
                    Image(systemName: "arrow.up.forward")
                }
                Button { onAction(.copy(server)) } label: {
                    Image(systemName: "doc.on.doc")
                }
                Button { onAction(.copyPID(server)) } label: {
                    Image(systemName: "number")
                }
                if !server.isProtected {
                    Button { onAction(.kill(server)) } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(Toast.Tint.failure.color.opacity(0.8))
                    }
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

struct FocusEarsView: View {
    let notchWidth: CGFloat
    let session: FocusSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let rem = Int(max(0, session.endDate.timeIntervalSince(context.date)))
            let text = String(format: "%02d:%02d", rem / 60, rem % 60)
            HStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Toast.Tint.waiting.color)
                    .frame(width: IslandLayout.earWidth)

                Spacer()
                    .frame(width: max(0, notchWidth))

                Text(text)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: IslandLayout.earWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct NotesTabView: View {
    let payload: NotesAndTasksPayload
    let onUpdateNote: (String) -> Void
    let onAddTask: (String) -> Void
    let onToggleTask: (UUID) -> Void
    let onRemoveTask: (UUID) -> Void

    @State private var newTaskText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Bento Box: Quick Scratchpad Note
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK NOTE")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                TextEditor(text: Binding(
                    get: { payload.note },
                    set: { onUpdateNote($0) }
                ))
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.92))
                .scrollContentBackground(.hidden)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Right Bento Box: Quick Tasks Checklist
            VStack(alignment: .leading, spacing: 6) {
                Text("TASKS")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 6) {
                    TextField("Add a task…", text: $newTaskText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white)
                        .onSubmit {
                            let t = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            onAddTask(t)
                            newTaskText = ""
                        }
                    Button {
                        let t = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        onAddTask(t)
                        newTaskText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(payload.tasks) { task in
                            HStack(spacing: 6) {
                                Button {
                                    onToggleTask(task.id)
                                } label: {
                                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(task.isDone ? Toast.Tint.success.color : .white.opacity(0.5))
                                }
                                .buttonStyle(.plain)

                                Text(task.title)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(task.isDone ? .white.opacity(0.4) : .white.opacity(0.9))
                                    .strikethrough(task.isDone)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Button {
                                    onRemoveTask(task.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.35))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AndroidDropTabView: View {
    let status: AndroidDropStatus
    let stagedFiles: [URL]
    let onToggleServer: () -> Void
    let onClearFiles: () -> Void
    var onAirDropFiles: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Bento Box: Wi-Fi QR Drop Server
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MAC ↔ ANDROID DROP")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Button(status.isRunning ? "Stop" : "Start Wi-Fi") {
                        onToggleServer()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(status.isRunning ? .black : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.isRunning ? Toast.Tint.success.color : Color.white.opacity(0.14), in: Capsule())
                }

                if status.isRunning, let data = status.qrPNGData, let img = NSImage(data: data), let urlStr = status.urlString {
                    HStack(spacing: 10) {
                        Image(nsImage: img)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 72, height: 72)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan with Android")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(urlStr)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            if status.receivedCount > 0 {
                                Text("Received \(status.receivedCount) file(s)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Toast.Tint.success.color)
                            }
                        }
                    }
                } else {
                    Text("Start Wi-Fi Drop to scan QR from Android and send or receive files.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Right Bento Box: Staged Files & NotchDrop Folder
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("STAGED (\(stagedFiles.count))")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    if !stagedFiles.isEmpty {
                        Button(action: onAirDropFiles) {
                            Label("AirDrop", systemImage: "wave.3.up.circle.fill")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Toast.Tint.info.color)
                        }
                        .buttonStyle(.plain)
                        Button("Clear", action: onClearFiles)
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                if stagedFiles.isEmpty {
                    Text("Drag files into the Notch to share them to Android.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(stagedFiles.prefix(4), id: \.self) { url in
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("NotchDrop", isDirectory: true)
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(dir)
                } label: {
                    Label("Open NotchDrop Folder", systemImage: "folder.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct BuildResultBentoCard: View {
    let result: BuildTestResult
    let onAction: (NotchStore.BuildAction) -> Void

    private var statusColor: Color {
        switch result.status {
        case .running: return Toast.Tint.info.color
        case .passed: return Toast.Tint.success.color
        case .failed: return Toast.Tint.failure.color
        case .cancelled: return Toast.Tint.waiting.color
        case .unknown: return .white.opacity(0.55)
        }
    }

    private var statusSymbol: String {
        switch result.status {
        case .running: return "hammer.fill"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .cancelled: return "stop.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text("\(result.project) · \(result.toolchain.displayName)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let duration = result.durationSeconds {
                    Text(String(format: "%.1fs", duration))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            HStack(spacing: 6) {
                if let loc = result.primaryLocation {
                    Text(loc.displayString)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(statusColor.opacity(0.9))
                        .lineLimit(1)
                }
                Text(result.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let loc = result.primaryLocation {
                    Button("Open File") {
                        onAction(.openLocation(loc))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.1), in: Capsule())
                }
                if result.status == .failed || result.rawLogSnippet != nil {
                    Button("Copy Error") {
                        onAction(.copyError(result))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WorklogEntryRow: View {
    let entry: WorklogEntry
    let showDate: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f
    }()

    private var iconAndColor: (String, Color) {
        switch entry.kind {
        case .agentWorking, .buildRunning:
            return ("cpu", Toast.Tint.info.color)
        case .agentWaiting:
            return ("hand.raised.fill", Toast.Tint.waiting.color)
        case .agentDone, .buildPassed, .devServerReady:
            return ("checkmark.circle.fill", Toast.Tint.success.color)
        case .agentFailed, .buildFailed, .devServerError:
            return ("xmark.circle.fill", Toast.Tint.failure.color)
        case .command:
            return (entry.isFailure ? "xmark.circle.fill" : "terminal.fill",
                    entry.isFailure ? Toast.Tint.failure.color : Toast.Tint.success.color)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                let (symbol, color) = iconAndColor
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)

                Text((showDate ? Self.dateTimeFormatter : Self.timeFormatter).string(from: entry.timestamp))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))

                Text(entry.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let project = entry.project, !project.isEmpty {
                    Text(project)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                if let duration = entry.duration {
                    Text(String(format: "%.1fs", duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if let exitCode = entry.exitCode {
                    Text("exit \(exitCode)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(exitCode == 0 ? Toast.Tint.success.color : Toast.Tint.failure.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            (exitCode == 0 ? Toast.Tint.success.color : Toast.Tint.failure.color).opacity(0.16),
                            in: Capsule()
                        )
                }
            }

            if let detail = entry.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .padding(.leading, 17)
            }

            if let ai = entry.aiExplanation, !ai.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Toast.Tint.info.color)
                    Text(ai)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Toast.Tint.info.color.opacity(0.95))
                        .lineLimit(2)
                }
                .padding(.leading, 17)
            }
        }
        .padding(.vertical, 2)
    }
}

