import Foundation
import Observation

/// The only mutable UI state. Everything flows in through `send(_:)` on the main actor.
@MainActor
@Observable
public final class NotchStore {
    public private(set) var state = NotchState()
    /// Geometry of the screen currently hosting the island (set by NotchWindowController).
    public internal(set) var geometry = ScreenGeometry.resolve(
        ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 0)
    )

    public enum DevServerAction: Sendable {
        case open(DevServer)
        case copy(DevServer)
        case kill(DevServer)
    }

    public enum ErrorLensAction: Sendable {
        case copy(String)
        case askAI(String)
    }

    public enum QuickToolAction: Sendable {
        case ocr
        case colorPicker
        case screenshotArea
        case screenshotFull
        case transformClipboard(TextTransformKind)
        case openCommandPalette
        case openQuickAI
        case openClipboard
    }

    public enum AudioAction: Sendable {
        case setVolume(Float)
        case toggleMute
        case selectDevice(UInt32)
        case refresh
    }

    @ObservationIgnored public var hoverExitDelay: Duration = .milliseconds(180)
    @ObservationIgnored public var onAction: (@MainActor (Toast.Action) -> Void)?
    @ObservationIgnored public var onServerAction: (@MainActor (DevServerAction) -> Void)?
    @ObservationIgnored public var onPasteClipboard: (@MainActor (ClipboardItem) -> Void)?
    @ObservationIgnored public var onCopyText: (@MainActor (String) -> Void)?
    @ObservationIgnored public var onErrorAction: (@MainActor (ErrorLensAction) -> Void)?
    @ObservationIgnored public var onRunTask: (@MainActor (RepoTask) -> Void)?
    @ObservationIgnored public var onAskAI: (@MainActor (String) -> Void)?
    @ObservationIgnored public var onMediaCommand: (@MainActor (MediaCommand) -> Void)?
    @ObservationIgnored public var onQuickTool: (@MainActor (QuickToolAction) -> Void)?
    @ObservationIgnored public var onAudioAction: (@MainActor (AudioAction) -> Void)?
    @ObservationIgnored public var onToggleAndroidDrop: (@MainActor () -> Void)?
    @ObservationIgnored public var onNotesUpdated: (@MainActor (NotesAndTasksPayload) -> Void)?
    @ObservationIgnored public var onFocusChanged: (@MainActor (FocusSession?) -> Void)?
    @ObservationIgnored public var onModeChanged: (@MainActor (NotchMode) -> Void)?
    @ObservationIgnored public var onToastShown: (@MainActor (Toast) -> Void)?
    @ObservationIgnored private var expiryTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var hoverExitTask: Task<Void, Never>?

    public init() {}

    public var mode: NotchMode { state.mode }

    public func send(_ event: NotchEvent) {
        let oldMode = state.mode
        let oldToast = state.activeToast
        let effects = NotchReducer.reduce(&state, event)
        effects.forEach(run)
        let newMode = state.mode
        if newMode != oldMode {
            onModeChanged?(newMode)
        }
        if let newToast = state.activeToast,
           newToast.id != oldToast?.id,
           (oldToast?.key == nil || newToast.key != oldToast?.key || newToast.tint != oldToast?.tint) {
            onToastShown?(newToast)
        }
    }

    public func post(_ toast: Toast) { send(.postToast(toast)) }

    public func perform(_ action: DevServerAction) {
        onServerAction?(action)
    }

    public func paste(_ item: ClipboardItem) {
        onPasteClipboard?(item)
    }

    public func copyTransformed(_ text: String) {
        onCopyText?(text)
    }

    public func openErrorLens(for toast: Toast) {
        guard let log = toast.errorLog else { return }
        send(.dismissToast)
        send(.openErrorLens(title: toast.subtitle ?? toast.title, log: log))
    }

    public func performErrorAction(_ action: ErrorLensAction) {
        onErrorAction?(action)
    }

    public func runTask(_ task: RepoTask) {
        onRunTask?(task)
    }

    public func askAI(_ prompt: String) {
        onAskAI?(prompt)
    }

    public func performMedia(_ command: MediaCommand) {
        onMediaCommand?(command)
    }

    public func performQuickTool(_ action: QuickToolAction) {
        onQuickTool?(action)
    }

    public func performAudio(_ action: AudioAction) {
        onAudioAction?(action)
    }

    public func toggleAndroidDrop() {
        onToggleAndroidDrop?()
    }

    public func updateNote(_ text: String) {
        send(.setQuickNote(text))
        onNotesUpdated?(state.notesPayload)
    }

    public func addTask(_ title: String) {
        send(.addQuickTask(title))
        onNotesUpdated?(state.notesPayload)
    }

    public func toggleTask(_ id: UUID) {
        send(.toggleQuickTask(id))
        onNotesUpdated?(state.notesPayload)
    }

    public func removeTask(_ id: UUID) {
        send(.removeQuickTask(id))
        onNotesUpdated?(state.notesPayload)
    }

    public func startFocus(minutes: Int) {
        send(.startFocus(minutes: minutes, at: .now))
        onFocusChanged?(state.focusSession)
    }

    public func stopFocus() {
        send(.stopFocus)
        onFocusChanged?(nil)
    }

    public func activate(_ toast: Toast) {
        guard let action = toast.action else { return }
        onAction?(action)
        send(.dismissToast)
    }

    /// Debounced on exit so brushing the edge doesn't make the island flicker.
    public func setHovering(_ hovering: Bool) {
        if hovering {
            hoverExitTask?.cancel()
            hoverExitTask = nil
            if !state.isHovering { send(.hoverChanged(true)) }
            return
        }
        guard state.isHovering, hoverExitTask == nil else { return }
        let delay = hoverExitDelay
        hoverExitTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.hoverExitTask = nil
            self.send(.hoverChanged(false))
        }
    }

    private func run(_ effect: NotchEffect) {
        switch effect {
        case .scheduleExpiry(let id, let after):
            expiryTasks[id]?.cancel()
            expiryTasks[id] = Task { [weak self] in
                try? await Task.sleep(for: after)
                guard !Task.isCancelled, let self else { return }
                self.expiryTasks[id] = nil
                self.send(.toastExpired(id))
            }
        case .cancelExpiry(let id):
            expiryTasks.removeValue(forKey: id)?.cancel()
        }
    }
}

