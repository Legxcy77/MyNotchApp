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
        let hasActiveAgents = store.state.hasActiveAgents
        let size = IslandLayout.size(for: mode, geometry: geometry, hasActiveAgents: hasActiveAgents)
        let radii = IslandLayout.radii(for: mode, geometry: geometry)
        let shape = UnevenRoundedRectangle(topLeadingRadius: radii.top, bottomLeadingRadius: radii.bottom,
                                           bottomTrailingRadius: radii.bottom, topTrailingRadius: radii.top,
                                           style: .continuous)

        content(mode: mode, geometry: geometry)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(.black, in: shape)
            .clipShape(shape)
            .shadow(color: .black.opacity(mode == .collapsed && !hasActiveAgents ? 0 : 0.4), radius: 20, y: 10)
            .padding(.top, geometry.topInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(Motion.morph, value: mode)
            .animation(Motion.morph, value: hasActiveAgents)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(mode: NotchMode, geometry: NotchGeometry) -> some View {
        ZStack(alignment: .top) {
            switch mode {
            case .collapsed:
                if store.state.hasActiveAgents {
                    CollapsedEarsView(
                        notchWidth: geometry.kind == .hardware ? geometry.baseSize.width : geometry.baseSize.width - 12,
                        workingCount: store.state.workingAgentCount,
                        waitingCount: store.state.waitingAgentCount
                    )
                    .transition(.islandContent)
                } else {
                    Color.clear
                }
            case .expanded:
                ExpandedView(
                    clearance: geometry.cameraClearance,
                    sessions: store.state.agentSessions,
                    servers: store.state.devServers,
                    stagedFiles: store.state.stagedFiles,
                    gitStatus: store.state.gitStatus,
                    onClearFinished: { store.send(.clearFinishedAgents) },
                    onServerAction: { store.perform($0) },
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
                    .id(toast.id) // swap content between queued toasts without morphing text
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
                    clearance: geometry.cameraClearance,
                    onPaste: { store.paste($0) },
                    onCopyTransformed: { store.copyTransformed($0) },
                    onClose: { store.send(.setClipboardOpen(false)) }
                )
                .transition(.islandContent)
            }
        }
    }
}

