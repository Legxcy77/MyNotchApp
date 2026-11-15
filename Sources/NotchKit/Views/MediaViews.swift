import AppKit
import SwiftUI

struct AudioControlBar: View {
    let audioState: AudioStateSnapshot
    let onAudioAction: (NotchStore.AudioAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onAudioAction(.toggleMute)
            } label: {
                Image(systemName: audioState.isMuted || audioState.volume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(audioState.isMuted ? Toast.Tint.waiting.color : .white.opacity(0.85))
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { Double(audioState.volume) },
                    set: { onAudioAction(.setVolume(Float($0))) }
                ),
                in: 0...1
            )
            .tint(.white)
            .controlSize(.mini)

            Text("\(Int(round(audioState.volume * 100)))%")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 34, alignment: .trailing)

            if !audioState.devices.isEmpty {
                let currentName = audioState.devices.first(where: \.isDefault)?.name ?? "Output"
                Menu {
                    ForEach(audioState.devices) { dev in
                        Button {
                            onAudioAction(.selectDevice(dev.id))
                        } label: {
                            HStack {
                                Text(dev.name)
                                if dev.isDefault { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "headphones")
                            .font(.system(size: 10.5))
                        Text(currentName)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.09), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            onAudioAction(.refresh)
        }
    }
}

struct MediaEarsView: View {
    let notchWidth: CGFloat
    let track: NowPlayingTrack

    var body: some View {
        HStack(spacing: 0) {
            artworkThumb
                .frame(width: IslandLayout.earWidth)

            Spacer()
                .frame(width: max(0, notchWidth))

            AudioBarsView(isPlaying: track.isPlaying)
                .frame(width: IslandLayout.earWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var artworkThumb: some View {
        if let data = track.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

private struct AudioBarsView: View {
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { idx in
                    let phase = t * 6.0 + Double(idx) * 1.3
                    let h: CGFloat = isPlaying ? CGFloat(4 + (sin(phase) * 0.5 + 0.5) * 9) : 3
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.85))
                        .frame(width: 2.2, height: h)
                }
            }
            .frame(height: 14, alignment: .center)
        }
    }
}

struct MediaExpandedView: View {
    let track: NowPlayingTrack?
    let lyrics: LRCDocument?
    let audioState: AudioStateSnapshot
    let onCommand: (MediaCommand) -> Void
    let onAudioAction: (NotchStore.AudioAction) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let track {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !track.isPlaying)) { context in
                    let position = track.currentPosition(at: context.date)
                    HStack(spacing: 12) {
                        playerColumn(track: track, position: position)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        lyricsColumn(position: position)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Nothing playing. Play Spotify, Apple Music, or browser media.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            AudioControlBar(audioState: audioState, onAudioAction: onAudioAction)
        }
    }

    private func playerColumn(track: NowPlayingTrack, position: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let data = track.artworkData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.source.uppercased())
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(track.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            VStack(spacing: 4) {
                GeometryReader { geo in
                    let fraction = track.duration > 0 ? min(1, max(0, position / track.duration)) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(.white.opacity(0.85))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(Self.formatTime(position))
                    Spacer()
                    if track.duration > 0 {
                        Text("-" + Self.formatTime(max(0, track.duration - position)))
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 20) {
                Spacer()
                Button { onCommand(.previous) } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button { onCommand(.togglePlayPause) } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)

                Button { onCommand(.next) } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }

    private func lyricsColumn(position: TimeInterval) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let lyrics, !lyrics.lines.isEmpty {
                let activeIndex = lyrics.currentLineIndex(at: position + 0.25)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(lyrics.lines) { line in
                                let isCurrent = lyrics.isSynced && line.id == activeIndex
                                let textColor: Color = lyrics.isSynced
                                    ? (isCurrent ? .white : .white.opacity(0.35))
                                    : .white.opacity(0.82)
                                Text(line.text)
                                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                                    .foregroundStyle(textColor)
                                    .scaleEffect(isCurrent ? 1.03 : 1.0, anchor: .leading)
                                    .animation(.easeInOut(duration: 0.22), value: isCurrent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: activeIndex) { _, newValue in
                        guard lyrics.isSynced, let newValue else { return }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                Text(lyrics.sourceLabel)
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                Text("No synced lyrics")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

