import SwiftUI

enum Motion {
    static let morph = Animation.spring(response: 0.42, dampingFraction: 0.8)
    /// Content arrives after the shape has started growing, and leaves before it shrinks.
    static let contentIn = Animation.easeOut(duration: 0.22).delay(0.1)
    static let contentOut = Animation.easeIn(duration: 0.08)
}

extension AnyTransition {
    static var islandContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).animation(Motion.contentIn),
            removal: .opacity.animation(Motion.contentOut)
        )
    }
}

extension Toast.Tint {
    var color: Color {
        switch self {
        case .neutral: .white
        case .success: Color(red: 0.30, green: 0.85, blue: 0.45)
        case .failure: Color(red: 1.00, green: 0.33, blue: 0.32)
        case .waiting: Color(red: 1.00, green: 0.66, blue: 0.20)
        case .info: Color(red: 0.36, green: 0.62, blue: 1.00)
        }
    }
}

public struct NotchRootView: View {
    let store: NotchStore

    public init(store: NotchStore) { self.store = store }

    public var body: some View {
        let mode = store.mode
        let geometry = store.geometry
        let showsCustomStatEars = store.widgetConfig.isEnabled(.earsSystemStats)
            && store.widgetConfig.notchDisplayMode == .fixed
            && (store.widgetConfig.leftEarStat != .none || store.widgetConfig.rightEarStat != .none)
        let showsEars = store.state.showsEars || showsCustomStatEars
        let isFaceScanning = store.state.faceScanEar != nil
        let hasCockpitSignal = store.state.hasCockpitSignal
        let hasCockpitDetail = store.state.latestBuildResult?.status == .failed
            && store.state.latestBuildResult?.primaryLocation != nil
        let size = IslandLayout.size(
            for: mode,
            geometry: geometry,
            hasActiveAgents: showsEars,
            isFaceScanning: isFaceScanning,
            hasCockpitSignal: hasCockpitSignal,
            hasCockpitDetail: hasCockpitDetail
        )
        let radii = IslandLayout.radii(for: mode, geometry: geometry)
        let earRadius: CGFloat = geometry.kind == .hardware ? 8 : 0
        let shape = NotchIslandShape(
            topEarRadius: earRadius,
            topCornerRadius: radii.top,
            bottomCornerRadius: radii.bottom
        )

        content(mode: mode, geometry: geometry)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(.black.opacity(store.widgetConfig.islandOpacity), in: shape)
            .clipShape(shape)
            .overlay {
                if store.widgetConfig.isEnabled(.edgeGlow) {
                    if case .toast(let toast) = mode {
                        shape
                            .stroke(toast.tint.color.opacity(0.55), lineWidth: 1.5)
                            .blur(radius: 1.2)
                    } else if !store.state.agentSessions.isEmpty {
                        shape
                            .stroke(Toast.Tint.info.color.opacity(0.45), lineWidth: 1.5)
                            .blur(radius: 1.2)
                    }
                }
            }
            .shadow(color: .black.opacity(mode == .collapsed && !showsEars ? 0 : 0.4), radius: 20, y: 10)
            .padding(.top, geometry.topInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(Motion.morph, value: mode)
            .animation(Motion.morph, value: showsEars)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(mode: NotchMode, geometry: NotchGeometry) -> some View {
        ZStack(alignment: .top) {
            switch mode {
            case .collapsed:
                let earSpacerWidth = geometry.kind == .hardware ? geometry.baseSize.width : geometry.baseSize.width - 12
                if let faceScan = store.state.faceScanEar {
                    FaceScanEarsView(notchWidth: earSpacerWidth, status: faceScan)
                        .transition(.islandContent)
                } else if store.state.hasActiveAgents {
                    CollapsedEarsView(
                        notchWidth: earSpacerWidth,
                        workingCount: store.state.workingAgentCount,
                        waitingCount: store.state.waitingAgentCount
                    )
                    .transition(.islandContent)
                } else if let meeting = store.state.nextMeeting,
                          MeetingDetector.isWithinCountdownWindow(meeting) {
                    MeetingEarsView(notchWidth: earSpacerWidth, meeting: meeting)
                        .transition(.islandContent)
                } else if let track = store.state.nowPlaying, track.isPlaying {
                    MediaEarsView(notchWidth: earSpacerWidth, track: track)
                        .transition(.islandContent)
                } else if store.state.hasCockpitSignal {
                    CockpitEarsView(
                        notchWidth: earSpacerWidth,
                        notchHeight: geometry.baseSize.height,
                        buildResult: store.state.latestBuildResult,
                        gitStatus: store.state.gitStatus,
                        devServers: store.state.devServers,
                        hasConflict: !store.state.agentConflicts.isEmpty
                    )
                    .transition(.islandContent)
                } else if store.widgetConfig.isEnabled(.earsSystemStats),
                          store.widgetConfig.notchDisplayMode == .fixed,
                          store.widgetConfig.leftEarStat != .none || store.widgetConfig.rightEarStat != .none {
                    SystemStatEarsView(
                        notchWidth: earSpacerWidth,
                        leftStat: store.widgetConfig.leftEarStat,
                        rightStat: store.widgetConfig.rightEarStat,
                        pulse: store.state.systemPulse.last
                    )
                    .transition(.islandContent)
                } else {
                    Color.clear
                }
            case .expanded:
                let latestClip = store.state.clipboard.items.compactMap { item -> String? in
                    if case .text(let t) = item.content { return t }
                    return nil
                }.first
                ExpandedView(
                    clearance: geometry.cameraClearance,
                    expandedTab: store.state.expandedTab,
                    sessions: store.state.agentSessions,
                    servers: store.state.devServers,
                    dockerContainers: store.state.dockerContainers,
                    stagedFiles: store.state.stagedFiles,
                    gitStatus: store.state.gitStatus,
                    runHistory: store.state.runHistory,
                    nowPlaying: store.state.nowPlaying,
                    lyrics: store.state.lyrics,
                    nextMeeting: store.state.nextMeeting,
                    focusSession: store.state.focusSession,
                    focusDurationMinutes: store.state.focusDurationMinutes,
                    systemPulse: store.state.systemPulse,
                    audioState: store.state.audioState,
                    notesPayload: store.state.notesPayload,
                    androidDrop: store.state.androidDrop,
                    latestClipboardText: latestClip,
                    latestBuildResult: store.state.latestBuildResult,
                    agentConflicts: store.state.agentConflicts,
                    worklogEntries: store.state.worklogEntries,
                    worklogRange: store.state.worklogRange,
                    releaseReadiness: store.state.releaseReadiness,
                    changeImpact: store.state.changeImpact,
                    envGuardReport: store.state.envGuardReport,
                    ciRuns: store.state.ciRuns,
                    databaseReport: store.state.databaseReport,
                    dependencyFindings: store.state.dependencyFindings,
                    widgetConfig: store.widgetConfig,
                    onSelectTab: { store.send(.setExpandedTab($0)) },
                    onClearFinished: { store.send(.clearFinishedAgents) },
                    onClearRunHistory: { store.send(.clearRunHistory) },
                    onServerAction: { store.perform($0) },
                    onMediaCommand: { store.performMedia($0) },
                    onAudioAction: { store.performAudio($0) },
                    onAdjustLyricsOffset: { store.adjustLyricsOffset($0) },
                    onAirDropFiles: { store.airDropStagedFiles() },
                    onDockerAction: { store.performDocker($0) },
                    onBuildAction: { store.performBuild($0) },
                    onSelectWorklogRange: { store.selectWorklogRange($0) },
                    onClearWorklog: { store.clearWorklog() },
                    onQuickTool: { store.performQuickTool($0) },
                    onJoinMeeting: { NSWorkspace.shared.open($0) },
                    onStartFocus: { store.startFocus(minutes: $0) },
                    onStopFocus: { store.stopFocus() },
                    onSelectFocusMinutes: { store.send(.setFocusDuration($0)) },
                    onUpdateNote: { store.updateNote($0) },
                    onAddTask: { store.addTask($0) },
                    onToggleTask: { store.toggleTask($0) },
                    onRemoveTask: { store.removeTask($0) },
                    onToggleAndroidDrop: { store.toggleAndroidDrop() },
                    onRemoveFile: { store.send(.removeStagedFile($0)) },
                    onClearFiles: { store.send(.clearStagedFiles) }
                )
                .transition(.islandContent)
            case .toast(let toast):
                let tapHandler: (() -> Void)? = if toast.errorLog != nil {
                    { store.openErrorLens(for: toast) }
                } else if toast.action != nil {
                    { store.activate(toast) }
                } else {
                    nil
                }
                ToastView(
                    toast: toast,
                    clearance: geometry.cameraClearance,
                    onTap: tapHandler
                )
                    .id(toast.key ?? toast.id.uuidString) // preserve view identity for keyed in-place updates (no flicker)
                    .transition(.islandContent)
            case .errorLens(let title, let log):
                ErrorLensView(
                    title: title,
                    log: log,
                    clearance: geometry.cameraClearance,
                    onCopy: { store.performErrorAction(.copy(log)) },
                    onAskAI: { store.performErrorAction(.askAI(log)) },
                    onClose: { store.send(.closeErrorLens) }
                )
                .transition(.islandContent)
            case .fileDrop:
                Label("Drop to stage", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, geometry.cameraClearance)
                    .transition(.islandContent)
            case .clipboard:
                ClipboardView(
                    history: store.state.clipboard,
                    isPaused: store.state.isClipboardPaused,
                    clearance: geometry.cameraClearance,
                    onPaste: { store.paste($0) },
                    onCopyTransformed: { store.copyTransformed($0) },
                    onTogglePause: { store.send(.toggleClipboardPaused) },
                    onClose: { store.send(.setClipboardOpen(false)) }
                )
                .transition(.islandContent)
            case .commandPalette:
                CommandPaletteView(
                    tasks: store.state.repoTasks,
                    repoName: store.state.activeRepoPath.map { ($0 as NSString).lastPathComponent },
                    clearance: geometry.cameraClearance,
                    onRun: { store.runTask($0) },
                    onClose: { store.send(.setCommandPaletteOpen(false)) }
                )
                .transition(.islandContent)
            case .quickAI:
                let latestClip = store.state.clipboard.items.compactMap { item -> String? in
                    if case .text(let t) = item.content { return t }
                    return nil
                }.first
                QuickAIView(
                    clearance: geometry.cameraClearance,
                    prompt: store.state.aiPrompt,
                    messages: store.state.aiMessages,
                    isLoading: store.state.isAILoading,
                    latestClipboardText: latestClip,
                    onPromptChange: { store.send(.setAIPrompt($0)) },
                    onSubmit: { store.askAI($0) },
                    onClearChat: { store.send(.clearAIChat) },
                    onClose: { store.send(.setQuickAIOpen(false)) }
                )
                .transition(.islandContent)
            }
        }
    }
}

private struct CockpitEarsView: View {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let buildResult: BuildTestResult?
    let gitStatus: GitStatus?
    let devServers: [DevServer]
    let hasConflict: Bool

    var body: some View {
        let tint: Color = {
            if buildResult?.status == .failed || hasConflict { return Toast.Tint.failure.color }
            if buildResult?.status == .running { return Toast.Tint.waiting.color }
            if !devServers.isEmpty { return Toast.Tint.success.color }
            if (gitStatus?.dirtyCount ?? 0) > 0 { return Toast.Tint.waiting.color }
            return Toast.Tint.info.color
        }()

        let leftLabel: String = {
            if let b = buildResult, b.status == .failed || b.status == .running {
                return "\(b.project) · \(b.kind.rawValue)"
            }
            if hasConflict { return "Agent conflict" }
            if let s = devServers.first {
                return "localhost:\(s.port)"
            }
            if let g = gitStatus {
                return "\(g.repoName) · \(g.branch)"
            }
            return "Workspace"
        }()

        let rightLabel: String = {
            if let b = buildResult, b.status == .failed {
                return "Failed"
            }
            if let b = buildResult, b.status == .running {
                return "Running"
            }
            if hasConflict { return "Conflict" }
            if let s = devServers.first {
                return s.associatedProject ?? "Live"
            }
            if let dirty = gitStatus?.dirtyCount, dirty > 0 {
                return "\(dirty) Modified"
            }
            return "Active"
        }()

        let detailLine: String? = {
            if buildResult?.status == .failed, let loc = buildResult?.primaryLocation?.displayString {
                return loc
            }
            return nil
        }()

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                    Text(leftLabel)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(width: IslandLayout.cockpitEarWidth, alignment: .trailing)

                Spacer().frame(width: notchWidth)

                HStack(spacing: 5) {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                    Text(rightLabel)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(width: IslandLayout.cockpitEarWidth, alignment: .leading)
            }
            .frame(height: notchHeight)

            if let detailLine {
                HStack(spacing: 4) {
                    Text("↳ \(detailLine)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(height: IslandLayout.cockpitDetailHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

