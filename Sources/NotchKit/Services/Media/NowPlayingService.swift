import AppKit
import Foundation
import os

public enum MediaCommand: Sendable {
    case togglePlayPause
    case next
    case previous
}

@MainActor
public protocol NowPlayingProvider: AnyObject {
    func start(onChange: @escaping @MainActor (NowPlayingTrack?) -> Void)
    func stop()
    func perform(_ command: MediaCommand)
}

@MainActor
public final class NowPlayingService {
    private let providers: [any NowPlayingProvider]
    private var activeSource: String?
    private var latestByProvider: [String: NowPlayingTrack] = [:]
    private let onChange: @MainActor (NowPlayingTrack?) -> Void

    public init(onChange: @escaping @MainActor (NowPlayingTrack?) -> Void) {
        self.onChange = onChange
        self.providers = [
            SpotifyMusicNowPlayingProvider(),
            MediaRemoteNowPlayingProvider()
        ]
    }

    public func start() {
        for provider in providers {
            let key = String(describing: type(of: provider))
            provider.start { [weak self] track in
                guard let self else { return }
                if let track {
                    self.latestByProvider[key] = track
                    if track.isPlaying || self.activeSource == nil || self.activeSource == track.source {
                        self.activeSource = track.source
                        self.onChange(track)
                    }
                } else {
                    self.latestByProvider.removeValue(forKey: key)
                    if let fallback = self.latestByProvider.values.first(where: \.isPlaying) ?? self.latestByProvider.values.first {
                        self.activeSource = fallback.source
                        self.onChange(fallback)
                    } else {
                        self.activeSource = nil
                        self.onChange(nil)
                    }
                }
            }
        }
    }

    public func stop() {
        for provider in providers {
            provider.stop()
        }
    }

    public func perform(_ command: MediaCommand) {
        if activeSource == "Spotify" || activeSource == "Apple Music" {
            providers.first?.perform(command)
        } else {
            providers.last?.perform(command)
        }
    }
}

// MARK: - Public API Provider (DistributedNotificationCenter + AppleScript)

@MainActor
final class SpotifyMusicNowPlayingProvider: NowPlayingProvider {
    private var observers: [NSObjectProtocol] = []
    private var onChange: (@MainActor (NowPlayingTrack?) -> Void)?
    private var artworkTask: Task<Void, Never>?
    private var lastSourceApp: String = "Spotify"

    func start(onChange: @escaping @MainActor (NowPlayingTrack?) -> Void) {
        self.onChange = onChange
        let center = DistributedNotificationCenter.default()

        let spotifyObs = center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let payload = Self.extractPayload(from: note.userInfo)
            Task { @MainActor [weak self] in
                self?.handlePayload(source: "Spotify", payload: payload)
            }
        }

        let musicObs = center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let payload = Self.extractPayload(from: note.userInfo)
            Task { @MainActor [weak self] in
                self?.handlePayload(source: "Apple Music", payload: payload)
            }
        }

        observers = [spotifyObs, musicObs]
        probeRunningPlayers()
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        for obs in observers {
            center.removeObserver(obs)
        }
        observers.removeAll()
        artworkTask?.cancel()
    }

    func perform(_ command: MediaCommand) {
        let appName = lastSourceApp
        let verb = switch command {
        case .togglePlayPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        }
        Task.detached(priority: .userInitiated) {
            _ = Self.runAppleScript("tell application \"\(appName)\" to \(verb)")
        }
    }

    private struct PlaybackNotePayload: Sendable {
        let stateStr: String
        let title: String?
        let artist: String
        let album: String?
        let duration: TimeInterval
        let position: TimeInterval
    }

    private nonisolated static func extractPayload(from userInfo: [AnyHashable: Any]?) -> PlaybackNotePayload? {
        guard let info = userInfo else { return nil }
        let stateStr = (info["Player State"] as? String ?? "").lowercased()
        let title = info["Name"] as? String
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String
        let rawDuration = (info["Total Time"] as? Double) ?? (info["Duration"] as? Double) ?? 0
        let duration = rawDuration > 10_000 ? rawDuration / 1000.0 : rawDuration
        let position = info["Playback Position"] as? Double ?? 0
        return PlaybackNotePayload(
            stateStr: stateStr,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position
        )
    }

    private func handlePayload(source: String, payload: PlaybackNotePayload?) {
        guard let payload else { return }
        if payload.stateStr == "stopped" {
            onChange?(nil)
            return
        }
        guard let title = payload.title, !title.isEmpty else { return }
        let isPlaying = payload.stateStr == "playing"

        lastSourceApp = source == "Apple Music" ? "Music" : "Spotify"
        let track = NowPlayingTrack(
            title: title,
            artist: payload.artist,
            album: payload.album,
            source: source,
            isPlaying: isPlaying,
            duration: payload.duration,
            anchorPosition: payload.position,
            anchorDate: .now,
            artworkData: nil
        )
        onChange?(track)
        fetchPositionAndArtwork(for: track, appName: lastSourceApp)
    }

    private func probeRunningPlayers() {
        let apps = NSWorkspace.shared.runningApplications
        if apps.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) {
            probe(appName: "Spotify", displaySource: "Spotify")
        } else if apps.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            probe(appName: "Music", displaySource: "Apple Music")
        }
    }

    private func probe(appName: String, displaySource: String) {
        Task.detached(priority: .utility) { [weak self] in
            let script = """
            tell application "\(appName)"
                if player state is stopped then return "STOPPED"
                set s to player state as string
                set n to name of current track
                set ar to artist of current track
                set al to album of current track
                set d to duration of current track
                set p to player position
                return s & "|||" & n & "|||" & ar & "|||" & al & "|||" & (d as string) & "|||" & (p as string)
            end tell
            """
            guard let output = Self.runAppleScript(script), output != "STOPPED" else { return }
            let parts = output.components(separatedBy: "|||")
            guard parts.count >= 6 else { return }
            let isPlaying = parts[0].lowercased() == "playing"
            let rawDur = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
            let duration = rawDur > 10_000 ? rawDur / 1000.0 : rawDur
            let pos = Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0
            let track = NowPlayingTrack(
                title: parts[1],
                artist: parts[2],
                album: parts[3].isEmpty ? nil : parts[3],
                source: displaySource,
                isPlaying: isPlaying,
                duration: duration,
                anchorPosition: pos,
                anchorDate: .now
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.lastSourceApp = appName
                self.onChange?(track)
                self.fetchPositionAndArtwork(for: track, appName: appName)
            }
        }
    }

    private func fetchPositionAndArtwork(for track: NowPlayingTrack, appName: String) {
        artworkTask?.cancel()
        artworkTask = Task.detached(priority: .utility) { [weak self] in
            let posOut = Self.runAppleScript("tell application \"\(appName)\" to return player position as string")
            let pos = posOut.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }

            var artData: Data?
            if appName == "Spotify",
               let urlStr = Self.runAppleScript("tell application \"Spotify\" to return artwork url of current track"),
               let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                artData = try? await URLSession.shared.data(from: url).0
            } else if appName == "Music" {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mynotch-art-\(UUID().uuidString).jpg")
                let script = """
                tell application "Music"
                    if (count of artworks of current track) > 0 then
                        set artBytes to raw data of artwork 1 of current track
                        set f to open for access POSIX file "\(tmp.path)" with write permission
                        write artBytes to f
                        close access f
                    end if
                end tell
                """
                _ = Self.runAppleScript(script)
                artData = try? Data(contentsOf: tmp)
                try? FileManager.default.removeItem(at: tmp)
            }

            if Task.isCancelled { return }
            let updated = NowPlayingTrack(
                title: track.title,
                artist: track.artist,
                album: track.album,
                source: track.source,
                isPlaying: track.isPlaying,
                duration: track.duration,
                anchorPosition: pos ?? track.anchorPosition,
                anchorDate: .now,
                artworkData: artData
            )
            await MainActor.run { [weak self] in
                self?.onChange?(updated)
            }
        }
    }

    private nonisolated static func runAppleScript(_ source: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

// MARK: - Optional Private API Provider (MediaRemote via Apple-signed /usr/bin/perl bridge)

@MainActor
final class MediaRemoteNowPlayingProvider: NowPlayingProvider {
    private struct BridgeSnapshot: Decodable, Sendable {
        let empty: Bool?
        let title: String?
        let artist: String?
        let album: String?
        let source: String?
        let duration: Double?
        let elapsed: Double?
        let playbackRate: Double?
        let artworkBase64: String?
    }

    private var process: Process?
    private var outputHandle: FileHandle?
    private var onChange: (@MainActor (NowPlayingTrack?) -> Void)?
    private var dylibPath: String?

    isolated deinit {
        outputHandle?.readabilityHandler = nil
        if let process, process.isRunning {
            process.terminate()
        }
    }

    func start(onChange: @escaping @MainActor (NowPlayingTrack?) -> Void) {
        self.onChange = onChange
        guard let dylib = Self.resolveDylibPath() else { return }
        self.dylibPath = dylib

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [
            "-MDynaLoader",
            "-e",
            "my $l = DynaLoader::dl_load_file($ARGV[0]) or die $!; my $s = DynaLoader::dl_find_symbol($l, 'mr_stream') or die; DynaLoader::dl_install_xsub('main::mr_stream', $s); mr_stream();",
            dylib
        ]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()

        let handle = pipe.fileHandleForReading
        let bufferState = OSAllocatedUnfairLock(initialState: Data())

        handle.readabilityHandler = { [weak self] fh in
            let chunk = fh.availableData
            guard !chunk.isEmpty else {
                fh.readabilityHandler = nil
                return
            }
            let lines: [Data] = bufferState.withLock { buffer in
                buffer.append(chunk)
                var extracted: [Data] = []
                while let nl = buffer.firstIndex(of: 0x0A) {
                    extracted.append(Data(buffer[..<nl]))
                    buffer.removeSubrange(...nl)
                }
                return extracted
            }

            for lineData in lines where !lineData.isEmpty {
                guard let snap = try? JSONDecoder().decode(BridgeSnapshot.self, from: lineData) else { continue }
                Task { @MainActor [weak self] in
                    self?.apply(snap)
                }
            }
        }

        do {
            try p.run()
            self.process = p
            self.outputHandle = handle
        } catch {
            handle.readabilityHandler = nil
        }
    }

    func stop() {
        outputHandle?.readabilityHandler = nil
        outputHandle = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }

    func perform(_ command: MediaCommand) {
        guard let dylibPath else { return }
        let symbol = switch command {
        case .togglePlayPause: "mr_cmd_toggle"
        case .next: "mr_cmd_next"
        case .previous: "mr_cmd_prev"
        }
        Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            p.arguments = [
                "-MDynaLoader",
                "-e",
                "my $l = DynaLoader::dl_load_file($ARGV[0]) or exit 1; my $s = DynaLoader::dl_find_symbol($l, $ARGV[1]) or exit 1; DynaLoader::dl_install_xsub('main::mr_cmd', $s); mr_cmd();",
                dylibPath,
                symbol
            ]
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            try? p.run()
            p.waitUntilExit()
        }
    }

    private func apply(_ snap: BridgeSnapshot) {
        if snap.empty == true {
            onChange?(nil)
            return
        }
        guard let title = snap.title, !title.isEmpty else { return }
        let artworkData = snap.artworkBase64.flatMap { $0.isEmpty ? nil : Data(base64Encoded: $0) }
        let track = NowPlayingTrack(
            title: title,
            artist: snap.artist ?? "",
            album: snap.album?.isEmpty == true ? nil : snap.album,
            source: snap.source ?? "Now Playing",
            isPlaying: (snap.playbackRate ?? 0) > 0,
            duration: snap.duration ?? 0,
            anchorPosition: snap.elapsed ?? 0,
            anchorDate: .now,
            artworkData: artworkData
        )
        onChange?(track)
    }

    private static func resolveDylibPath() -> String? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteBridge.dylib").path,
           FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        let devPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MyNotchApp/build/MyNotchApp.app/Contents/Resources/MediaRemoteBridge.dylib").path
        return FileManager.default.fileExists(atPath: devPath) ? devPath : nil
    }
}
