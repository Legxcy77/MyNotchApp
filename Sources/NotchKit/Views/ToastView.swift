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
    let audioState: AudioStateSnapshot
    let notesPayload: NotesAndTasksPayload
    let androidDrop: AndroidDropStatus
    let latestClipboardText: String?
    let onSelectTab: (ExpandedTab) -> Void
    let onClearFinished: () -> Void
    let onClearRunHistory: () -> Void
    let onServerAction: (NotchStore.DevServerAction) -> Void
    let onMediaCommand: (MediaCommand) -> Void
    let onAudioAction: (NotchStore.AudioAction) -> Void
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
                        ExpandedTabPill(symbol: "note.text", title: nil, isSelected: expandedTab == .notes) {
                            onSelectTab(.notes)
                        }
                        ExpandedTabPill(symbol: "iphone.and.arrow.forward", title: nil, isSelected: expandedTab == .drop) {
                            onSelectTab(.drop)
                        }
                        ExpandedTabPill(symbol: "timer", title: nil, isSelected: expandedTab == .focus) {
                            onSelectTab(.focus)
                        }
                        ExpandedTabPill(symbol: "camera.fill", title: nil, isSelected: expandedTab == .mirror) {
                            onSelectTab(.mirror)
                        }
                        ExpandedTabPill(symbol: "clock.arrow.circlepath", title: runHistory.isEmpty ? nil : "\(runHistory.count)", isSelected: expandedTab == .timeline) {
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
                    } else if expandedTab == .timeline && !runHistory.isEmpty {
                        Button("Clear", action: onClearRunHistory)
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
                    onAudioAction: onAudioAction
                )
            } else if expandedTab == .tools {
                ToolsTabView(latestClipboardText: latestClipboardText, onAction: onQuickTool)
            } else if expandedTab == .notes {
                NotesTabView(
                    payload: notesPayload,
                    onUpdateNote: onUpdateNote,
                    onAddTask: onAddTask,
                    onToggleTask: onToggleTask,
                    onRemoveTask: onRemoveTask
                )
            } else if expandedTab == .drop {
                AndroidDropTabView(
                    status: androidDrop,
                    stagedFiles: stagedFiles,
                    onToggleServer: onToggleAndroidDrop,
                    onClearFiles: onClearFiles
                )
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
                    bentoBox {
                        Text("No completed commands or agent runs yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    bentoBox {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(runHistory) { record in
                                    RunTimelineRow(record: record)
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

            if !sessions.isEmpty || !servers.isEmpty || !stagedFiles.isEmpty {
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
                        if !stagedFiles.isEmpty {
                            HStack(spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(stagedFiles, id: \.self) { url in
                                            StagedFileChip(url: url) { onRemoveFile(url) }
                                        }
                                    }
                                }
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

