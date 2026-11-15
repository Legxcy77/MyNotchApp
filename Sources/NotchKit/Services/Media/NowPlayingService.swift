import AppKit
import Foundation

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

// MARK: - Optional Private API Provider (MediaRemote.framework behind protocol)

@MainActor
final class MediaRemoteNowPlayingProvider: NowPlayingProvider {
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCmdFn = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool

    private var handle: UnsafeMutableRawPointer?
    private var getInfo: GetInfoFn?
    private var sendCmd: SendCmdFn?
    private var observers: [NSObjectProtocol] = []
    private var onChange: (@MainActor (NowPlayingTrack?) -> Void)?

    func start(onChange: @escaping @MainActor (NowPlayingTrack?) -> Void) {
        self.onChange = onChange
        guard let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
            return
        }
        handle = h
        if let regSym = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let reg = unsafeBitCast(regSym, to: RegisterFn.self)
            reg(.main)
        }
        if let infoSym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(infoSym, to: GetInfoFn.self)
        }
        if let cmdSym = dlsym(h, "MRMediaRemoteSendCommand") {
            sendCmd = unsafeBitCast(cmdSym, to: SendCmdFn.self)
        }

        let nc = NotificationCenter.default
        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ]
        observers = names.map { name in
            nc.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
        refresh()
    }

    func stop() {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
        }
        observers.removeAll()
        if let handle {
            dlclose(handle)
            self.handle = nil
        }
    }

    func perform(_ command: MediaCommand) {
        // MRMediaRemoteCommand: 2 = togglePlayPause, 4 = nextTrack, 5 = previousTrack
        let code: UInt32 = switch command {
        case .togglePlayPause: 2
        case .next: 4
        case .previous: 5
        }
        _ = sendCmd?(code, nil)
    }

    private func refresh() {
        guard let getInfo else { return }
        getInfo(.main) { [weak self] info in
            guard let self else { return }
            guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty else {
                return
            }
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let artwork = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            let source = info["kMRMediaRemoteNowPlayingInfoParentApplicationDisplayName"] as? String ?? "Now Playing"

            let track = NowPlayingTrack(
                title: title,
                artist: artist,
                album: album,
                source: source,
                isPlaying: rate > 0,
                duration: duration,
                anchorPosition: elapsed,
                anchorDate: .now,
                artworkData: artwork
            )
            self.onChange?(track)
        }
    }
}
