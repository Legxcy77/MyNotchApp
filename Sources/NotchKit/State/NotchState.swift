import Foundation

public enum NotchMode: Equatable, Sendable {
    case collapsed
    case expanded
    case fileDrop
    case toast(Toast)
}

public struct NotchState: Equatable, Sendable {
    public var isHovering = false
    public var isDragging = false
    public var activeToast: Toast?
    /// Sorted by priority (desc), FIFO within a priority.
    public var pendingToasts: [Toast] = []

    public init() {}

    /// Derived, never stored, so impossible states can't exist.
    public var mode: NotchMode {
        if isDragging { return .fileDrop }
        if let activeToast { return .toast(activeToast) }
        if isHovering { return .expanded }
        return .collapsed
    }
}

public enum NotchEvent: Sendable, Equatable {
    case hoverChanged(Bool)
    case dragChanged(Bool)
    case postToast(Toast)
    case toastExpired(UUID)
    case dismissToast
}

public enum NotchEffect: Sendable, Equatable {
    case scheduleExpiry(UUID, after: Duration)
    case cancelExpiry(UUID)
}

public enum NotchReducer {
    public static let maxPending = 8

    public static func reduce(_ s: inout NotchState, _ event: NotchEvent) -> [NotchEffect] {
        switch event {
        case .hoverChanged(let h):
            s.isHovering = h
            return []
        case .dragChanged(let d):
            s.isDragging = d
            return []
        case .postToast(let t):
            return post(t, into: &s)
        case .toastExpired(let id):
            guard s.activeToast?.id == id else { return [] } // stale timer
            return advance(&s)
        case .dismissToast:
            guard let current = s.activeToast else { return [] }
            return [.cancelExpiry(current.id)] + advance(&s)
        }
    }

    private static func post(_ t: Toast, into s: inout NotchState) -> [NotchEffect] {
        if let key = t.key {
            if let current = s.activeToast, current.key == key {
                s.activeToast = t
                return [.cancelExpiry(current.id), .scheduleExpiry(t.id, after: t.duration)]
            }
            if let i = s.pendingToasts.firstIndex(where: { $0.key == key }) {
                s.pendingToasts.remove(at: i)
                enqueue(t, into: &s)
                return []
            }
        }
        guard let current = s.activeToast else {
            s.activeToast = t
            return [.scheduleExpiry(t.id, after: t.duration)]
        }
        if t.priority > current.priority {
            // Preempted toast goes to the front of its priority band and gets a fresh timer later.
            let i = s.pendingToasts.firstIndex(where: { $0.priority <= current.priority }) ?? s.pendingToasts.endIndex
            s.pendingToasts.insert(current, at: i)
            s.activeToast = t
            trim(&s)
            return [.cancelExpiry(current.id), .scheduleExpiry(t.id, after: t.duration)]
        }
        enqueue(t, into: &s)
        return []
    }

    private static func enqueue(_ t: Toast, into s: inout NotchState) {
        let i = s.pendingToasts.firstIndex(where: { $0.priority < t.priority }) ?? s.pendingToasts.endIndex
        s.pendingToasts.insert(t, at: i)
        trim(&s)
    }

    private static func trim(_ s: inout NotchState) {
        if s.pendingToasts.count > maxPending { s.pendingToasts.removeLast(s.pendingToasts.count - maxPending) }
    }

    private static func advance(_ s: inout NotchState) -> [NotchEffect] {
        guard !s.pendingToasts.isEmpty else {
            s.activeToast = nil
            return []
        }
        let next = s.pendingToasts.removeFirst()
        s.activeToast = next
        return [.scheduleExpiry(next.id, after: next.duration)]
    }
}

