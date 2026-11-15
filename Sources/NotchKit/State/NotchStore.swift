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

    @ObservationIgnored public var hoverExitDelay: Duration = .milliseconds(180)
    @ObservationIgnored private var expiryTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var hoverExitTask: Task<Void, Never>?

    public init() {}

    public var mode: NotchMode { state.mode }

    public func send(_ event: NotchEvent) {
        let effects = NotchReducer.reduce(&state, event)
        effects.forEach(run)
    }

    public func post(_ toast: Toast) { send(.postToast(toast)) }

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

