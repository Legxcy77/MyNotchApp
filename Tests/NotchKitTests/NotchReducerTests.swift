import Foundation
import Testing
@testable import NotchKit

private func toast(_ title: String, key: String? = nil, priority: Toast.Priority = .normal) -> Toast {
    Toast(key: key, title: title, priority: priority)
}

@Suite struct NotchReducerTests {
    @Test func modePrecedence() {
        var s = NotchState()
        #expect(s.mode == .collapsed)
        s.isHovering = true
        #expect(s.mode == .expanded)
        let t = toast("a")
        _ = NotchReducer.reduce(&s, .postToast(t))
        #expect(s.mode == .toast(t))
        s.isDragging = true
        #expect(s.mode == .fileDrop)
    }

    @Test func firstToastSchedulesExpiry() {
        var s = NotchState()
        let t = toast("a")
        #expect(NotchReducer.reduce(&s, .postToast(t)) == [.scheduleExpiry(t.id, after: t.duration)])
    }

    @Test func samePriorityQueuesFIFO() {
        var s = NotchState()
        let a = toast("a"), b = toast("b"), c = toast("c")
        [a, b, c].forEach { _ = NotchReducer.reduce(&s, .postToast($0)) }
        #expect(s.activeToast == a)
        #expect(s.pendingToasts == [b, c])
        let fx = NotchReducer.reduce(&s, .toastExpired(a.id))
        #expect(s.activeToast == b)
        #expect(fx == [.scheduleExpiry(b.id, after: b.duration)])
    }

    @Test func higherPriorityPreemptsAndRequeuesCurrent() {
        var s = NotchState()
        let low = toast("low"), queued = toast("queued"), urgent = toast("urgent", priority: .critical)
        _ = NotchReducer.reduce(&s, .postToast(low))
        _ = NotchReducer.reduce(&s, .postToast(queued))
        let fx = NotchReducer.reduce(&s, .postToast(urgent))
        #expect(s.activeToast == urgent)
        #expect(s.pendingToasts == [low, queued]) // preempted goes ahead of its band
        #expect(fx == [.cancelExpiry(low.id), .scheduleExpiry(urgent.id, after: urgent.duration)])
    }

    @Test func staleExpiryIsIgnored() {
        var s = NotchState()
        let a = toast("a"), b = toast("b", priority: .high)
        _ = NotchReducer.reduce(&s, .postToast(a))
        _ = NotchReducer.reduce(&s, .postToast(b))
        #expect(NotchReducer.reduce(&s, .toastExpired(a.id)).isEmpty)
        #expect(s.activeToast == b)
    }

    @Test func keyedToastUpdatesInPlace() {
        var s = NotchState()
        let p1 = toast("10%", key: "deploy"), p2 = toast("60%", key: "deploy")
        _ = NotchReducer.reduce(&s, .postToast(p1))
        let fx = NotchReducer.reduce(&s, .postToast(p2))
        #expect(s.activeToast == p2)
        #expect(s.pendingToasts.isEmpty)
        #expect(fx == [.cancelExpiry(p1.id), .scheduleExpiry(p2.id, after: p2.duration)])
    }

    @Test func keyedToastReplacesQueuedCopy() {
        var s = NotchState()
        let a = toast("a"), q1 = toast("v1", key: "k"), q2 = toast("v2", key: "k")
        [a, q1, q2].forEach { _ = NotchReducer.reduce(&s, .postToast($0)) }
        #expect(s.pendingToasts == [q2])
    }

    @Test func queueIsBoundedDroppingLowestPriority() {
        var s = NotchState()
        _ = NotchReducer.reduce(&s, .postToast(toast("active", priority: .critical)))
        let low = toast("low", priority: .low)
        _ = NotchReducer.reduce(&s, .postToast(low))
        for i in 0..<NotchReducer.maxPending { _ = NotchReducer.reduce(&s, .postToast(toast("\(i)"))) }
        #expect(s.pendingToasts.count == NotchReducer.maxPending)
        #expect(!s.pendingToasts.contains(low))
    }

    @Test func dismissAdvancesAndCancels() {
        var s = NotchState()
        let a = toast("a"), b = toast("b")
        _ = NotchReducer.reduce(&s, .postToast(a))
        _ = NotchReducer.reduce(&s, .postToast(b))
        let fx = NotchReducer.reduce(&s, .dismissToast)
        #expect(fx == [.cancelExpiry(a.id), .scheduleExpiry(b.id, after: b.duration)])
        _ = NotchReducer.reduce(&s, .dismissToast)
        #expect(s.activeToast == nil)
        #expect(NotchReducer.reduce(&s, .dismissToast).isEmpty)
    }
}

@Suite @MainActor struct NotchStoreTests {
    @Test func toastExpiresThroughEffects() async throws {
        let store = NotchStore()
        store.post(Toast(title: "x", duration: .milliseconds(50)))
        #expect(store.state.activeToast != nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(store.state.activeToast == nil)
    }

    @Test func hoverExitIsDebouncedAndCancellable() async throws {
        let store = NotchStore()
        store.hoverExitDelay = .milliseconds(80)
        store.setHovering(true)
        store.setHovering(false)
        #expect(store.state.isHovering) // still hovering during debounce
        store.setHovering(true)         // re-enter cancels exit
        try await Task.sleep(for: .milliseconds(150))
        #expect(store.state.isHovering)
        store.setHovering(false)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!store.state.isHovering)
    }
}
