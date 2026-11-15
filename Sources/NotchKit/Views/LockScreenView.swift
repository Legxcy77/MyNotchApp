import AppKit
import SwiftUI

public enum LockPlayerPresentation: Equatable, Sendable {
    case compact
    case albumFocus
    case lyricsSplit
}

public struct LockScreenView: View {
    @Bindable var store: NotchStore
    @Bindable var faceAuth: FaceAuthService
    let onMediaCommand: (MediaCommand) -> Void
    let onAuthenticateWithSystem: () -> Void
    let onRetryFaceScan: () -> Void
    let onEmergencyClose: () -> Void
    let isSystemOverlay: Bool
    let onPresentationModeChange: ((LockPlayerPresentation) -> Void)?

    @State private var playerMode: LockPlayerPresentation = .albumFocus
    @Namespace private var playerNamespace

    public init(
        store: NotchStore,
        faceAuth: FaceAuthService,
        onMediaCommand: @escaping (MediaCommand) -> Void,
        onAuthenticateWithSystem: @escaping () -> Void,
        onRetryFaceScan: @escaping () -> Void,
        onEmergencyClose: @escaping () -> Void = {},
        isSystemOverlay: Bool = false,
        onPresentationModeChange: ((LockPlayerPresentation) -> Void)? = nil
    ) {
        self.store = store
        self.faceAuth = faceAuth
        self.onMediaCommand = onMediaCommand
        self.onAuthenticateWithSystem = onAuthenticateWithSystem
        self.onRetryFaceScan = onRetryFaceScan
        self.onEmergencyClose = onEmergencyClose
        self.isSystemOverlay = isSystemOverlay
        self.onPresentationModeChange = onPresentationModeChange
    }

    private var track: NowPlayingTrack? {
        store.state.nowPlaying
    }

    private var lyrics: LRCDocument? {
        store.state.lyrics
    }

    private var artworkImage: NSImage? {
        guard let data = track?.artworkData else { return nil }
        return NSImage(data: data)
    }

    public var body: some View {
        Group {
            if isSystemOverlay {
                systemOverlayBody
            } else {
                fullPreviewBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: playerMode)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: track?.trackKey)
        .onChange(of: playerMode) { _, newValue in
            onPresentationModeChange?(newValue)
        }
    }

    @ViewBuilder
    private var systemOverlayBody: some View {
        ZStack {
            if playerMode != .compact, let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 65)
                    .scaleEffect(1.16)
                    .opacity(0.68)
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.55), .black.opacity(0.18), .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            } else {
                Color.clear
            }

            VStack(spacing: 16) {
                if let track {
                    mediaStage(track: track)
                }

                HStack(spacing: 10) {
                    if store.state.workingAgentCount > 0 {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("\(store.state.workingAgentCount) agent running")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if faceAuth.hasEnrolledFace {
                notchFaceIDPill
            }
        }
    }

    @ViewBuilder
    private var notchFaceIDPill: some View {
        let isScanning = faceAuth.mode == .verifying || faceAuth.mode == .verified
        let isVerified = faceAuth.mode == .verified
        let awaitingBlink = faceAuth.verifyMessage.contains("กระพริบตา")
        let shortInstruction: String = isVerified
            ? "Success"
            : (awaitingBlink ? "กระพริบตา 1 ครั้ง" : (faceAuth.verifyMessage.contains("ไม่พบ") ? "ไม่พบใบหน้า" : "มองกล้อง"))
        let earWidth: CGFloat = isScanning ? 124 : 38
        let pillHeight: CGFloat = isScanning ? 42 : 38

        Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            onRetryFaceScan()
        } label: {
            HStack(spacing: 0) {
                // Left ear: Face ID icon + ring
                HStack(spacing: 6) {
                    ZStack {
                        if isScanning {
                            FaceScanSpinnerRing(
                                isVerifying: faceAuth.mode == .verifying,
                                isVerified: isVerified,
                                isAwaitingBlink: awaitingBlink,
                                lineWidth: 1.8
                            )
                            .frame(width: 20, height: 20)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                        Image(systemName: isVerified ? "checkmark" : "faceid")
                            .font(.system(size: isScanning ? 10.5 : 12, weight: .semibold))
                            .foregroundStyle(isVerified ? Color.green : Color.white.opacity(isScanning ? 0.95 : 0.72))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    if isScanning {
                        Text("Face ID")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize()
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
                    }
                }
                .frame(width: earWidth, height: pillHeight)
                .clipped()

                // Center camera spacer (never draw under hardware notch camera)
                Spacer()
                    .frame(width: 185)

                // Right ear: instruction while scanning, subtle hint when idle
                ZStack {
                    if isScanning {
                        Text(shortInstruction)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isVerified ? Color.green : (awaitingBlink ? Color.orange : Color.white.opacity(0.9)))
                            .lineLimit(1)
                            .fixedSize()
                            .id(shortInstruction)
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .transition(.opacity)
                    }
                }
                .frame(width: earWidth, height: pillHeight)
                .clipped()
            }
            .padding(.top, 4)
            .background(
                .black,
                in: NotchIslandShape(
                    topEarRadius: isScanning ? 10 : 8,
                    topCornerRadius: 0,
                    bottomCornerRadius: isScanning ? 18 : 14
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isScanning)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: faceAuth.mode)
        .animation(.easeOut(duration: 0.18), value: shortInstruction)
    }

    private var fullPreviewBody: some View {
        ZStack {
            backdropView

            VStack(spacing: 0) {
                clockHeader
                    .padding(.top, 56)

                Spacer()

                if let track {
                    mediaStage(track: track)
                }

                Spacer()

                unlockFooter
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 48)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onEmergencyClose) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Esc")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.trailing, 24)
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdropView: some View {
        ZStack {
            Color.black

            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 75)
                    .scaleEffect(1.18)
                    .opacity(0.65)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color.black,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            if store.widgetConfig.isEnabled(.lockScreenAurora) {
                AuroraMetalView(
                    palette: AuroraPalette.from(imageData: track?.artworkData),
                    intensity: store.widgetConfig.auroraIntensity * 0.55
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            Color.black.opacity(0.28)
                .ignoresSafeArea()
        }
    }

    // MARK: - Clock Header

    private var clockHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            VStack(spacing: 2) {
                Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))

                Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 86, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            }
        }
    }

    // MARK: - Media Stage (3 Morphing States)

    @ViewBuilder
    private func mediaStage(track: NowPlayingTrack) -> some View {
        TimelineView(.periodic(from: .now, by: track.isPlaying ? 0.25 : 1.0)) { context in
            let position = track.currentPosition(at: context.date)

            switch playerMode {
            case .compact:
                VStack {
                    Spacer()
                    compactPlayerPill(track: track, position: position)
                }
                .frame(maxHeight: 380)

            case .albumFocus:
                VStack(spacing: 18) {
                    albumArtworkCard(size: 325)
                        .onTapGesture {
                            playerMode = .compact
                        }

                    frostedPlayerCard(track: track, position: position, width: 350)
                }

            case .lyricsSplit:
                HStack(alignment: .center, spacing: 44) {
                    VStack(spacing: 16) {
                        albumArtworkCard(size: 290)
                            .onTapGesture {
                                playerMode = .compact
                            }

                        frostedPlayerCard(track: track, position: position, width: 320)
                    }

                    lockLyricsPanel(position: position)
                        .frame(width: 420, height: 370)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }

    @ViewBuilder
    private func albumArtworkCard(size: CGFloat) -> some View {
        Group {
            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.26, weight: .light))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.42), radius: 28, y: 14)
        .matchedGeometryEffect(id: "artwork", in: playerNamespace)
    }

    private func frostedPlayerCard(track: NowPlayingTrack, position: TimeInterval, width: CGFloat) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(track.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            progressScrubber(track: track, position: position)

            HStack(spacing: 0) {
                Spacer().frame(width: 24)
                Spacer()
                HStack(spacing: 22) {
                    Button { onMediaCommand(.previous) } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button { onMediaCommand(.togglePlayPause) } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17))
                    }
                    .buttonStyle(.plain)

                    Button { onMediaCommand(.next) } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white)

                Spacer()

                Button {
                    playerMode = (playerMode == .lyricsSplit) ? .albumFocus : .lyricsSplit
                } label: {
                    Image(systemName: playerMode == .lyricsSplit ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 13))
                        .foregroundStyle(playerMode == .lyricsSplit ? .white : .white.opacity(0.75))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
        .matchedGeometryEffect(id: "playerCard", in: playerNamespace)
    }

    private func compactPlayerPill(track: NowPlayingTrack, position: TimeInterval) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let artworkImage {
                        Image(nsImage: artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.12)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            )
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .matchedGeometryEffect(id: "artwork", in: playerNamespace)
                .onTapGesture {
                    playerMode = .albumFocus
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
                Spacer()
            }

            progressScrubber(track: track, position: position)

            HStack(spacing: 0) {
                Spacer().frame(width: 24)
                Spacer()
                HStack(spacing: 24) {
                    Button { onMediaCommand(.previous) } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button { onMediaCommand(.togglePlayPause) } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17))
                    }
                    .buttonStyle(.plain)

                    Button { onMediaCommand(.next) } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white)

                Spacer()

                Button {
                    playerMode = .lyricsSplit
                } label: {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.32), radius: 22, y: 12)
        .matchedGeometryEffect(id: "playerCard", in: playerNamespace)
    }

    private func progressScrubber(track: NowPlayingTrack, position: TimeInterval) -> some View {
        let fraction = track.duration > 0 ? min(1, max(0, position / track.duration)) : 0
        let remaining = max(0, track.duration - position)
        return HStack(spacing: 8) {
            Text(Self.formatTime(position))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.24))
                        .frame(height: 3)

                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: max(4, geo.size.width * fraction), height: 3)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 10)

            Text("-\(Self.formatTime(remaining))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    @ViewBuilder
    private func lockLyricsPanel(position: TimeInterval) -> some View {
        Group {
        if let lyrics, !lyrics.lines.isEmpty {
            let activeIndex = lyrics.currentLineIndex(at: position + 0.25)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(lyrics.lines) { line in
                            let isCurrent = lyrics.isSynced && line.id == activeIndex
                            let color: Color = lyrics.isSynced
                                ? (isCurrent ? .white : .white.opacity(0.38))
                                : .white.opacity(0.82)
                            Text(line.text)
                                .font(.system(size: isCurrent ? 20 : 17, weight: isCurrent ? .bold : .medium))
                                .foregroundStyle(color)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(.easeInOut(duration: 0.22), value: isCurrent)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, 36)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: activeIndex) { _, newValue in
                    guard lyrics.isSynced, let newValue else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.35))
                Text("No lyrics available")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
        .overlay(alignment: .bottomTrailing) {
            if lyrics != nil {
                HStack(spacing: 6) {
                    Button("-0.5s") { store.adjustLyricsOffset(-0.5) }
                        .buttonStyle(.plain)
                    Button("+0.5s") { store.adjustLyricsOffset(0.5) }
                        .buttonStyle(.plain)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
            }
        }
    }

    // MARK: - Unlock Footer

    private var unlockFooter: some View {
        let userName = NSUserName()
        let initial = String(userName.prefix(1)).uppercased()

        return VStack(spacing: 10) {
            ZStack {
                if faceAuth.hasEnrolledFace {
                    FaceScanSpinnerRing(
                        isVerifying: faceAuth.mode == .verifying,
                        isVerified: faceAuth.mode == .verified,
                        isAwaitingBlink: faceAuth.verifyMessage.contains("กระพริบตา"),
                        lineWidth: 2.5
                    )
                    .frame(width: 58, height: 58)
                }

                Circle()
                    .fill(faceAuth.mode == .verified ? Color.green.opacity(0.25) : Color.white.opacity(0.22))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(
                                faceAuth.mode == .verified ? Color.green.opacity(0.75) : Color.white.opacity(0.25),
                                lineWidth: 0.75
                            )
                    )

                if faceAuth.mode == .verified {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(initial.isEmpty ? "U" : initial)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: faceAuth.mode)

            Text(userName)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 10) {
                if faceAuth.hasEnrolledFace {
                    Button(action: onRetryFaceScan) {
                        HStack(spacing: 8) {
                            ZStack {
                                FaceScanSpinnerRing(
                                    isVerifying: faceAuth.mode == .verifying,
                                    isVerified: faceAuth.mode == .verified,
                                    isAwaitingBlink: faceAuth.verifyMessage.contains("กระพริบตา"),
                                    lineWidth: 1.8
                                )
                                .frame(width: 20, height: 20)

                                Image(systemName: faceAuth.mode == .verified ? "checkmark" : "faceid")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(faceAuth.mode == .verified ? Color.green : Color.white.opacity(0.9))
                            }
                            Text(faceStatusText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    faceAuth.mode == .verified ? Color.green.opacity(0.8) : Color.white.opacity(0.22),
                                    lineWidth: 0.75
                                )
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: "faceid")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("ยังไม่ได้ลงทะเบียนใบหน้า (Menu → Setup Face Unlock…)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                    )
                }

                Button(action: onAuthenticateWithSystem) {
                    HStack(spacing: 6) {
                        Image(systemName: "touchid")
                            .font(.system(size: 13))
                        Text("Touch ID / รหัสผ่าน")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var faceStatusText: String {
        switch faceAuth.mode {
        case .verified:
            return "กำลังเข้าสู่ระบบ..."
        case .verifying:
            return faceAuth.verifyMessage
        case .failed(let message):
            return message
        case .idle, .enrolling, .enrolled:
            return "แตะเพื่อสแกนหน้า"
        }
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct FaceScanSpinnerRing: View {
    let isVerifying: Bool
    let isVerified: Bool
    let isAwaitingBlink: Bool
    let lineWidth: CGFloat

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)

            if isVerified {
                Circle()
                    .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .transition(.opacity)
            } else if isVerifying {
                Circle()
                    .trim(from: 0.0, to: 0.34)
                    .stroke(
                        isAwaitingBlink ? Color.green.opacity(0.95) : Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        rotation = 0
                        withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVerified)
    }
}

