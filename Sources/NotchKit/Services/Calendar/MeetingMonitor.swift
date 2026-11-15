import EventKit
import Foundation

@MainActor
public final class MeetingMonitor {
    private let eventStore = EKEventStore()
    private let onUpdate: @MainActor (UpcomingMeeting?) -> Void
    private var observer: NSObjectProtocol?
    private var timerTask: Task<Void, Never>?

    public init(onUpdate: @escaping @MainActor (UpcomingMeeting?) -> Void) {
        self.onUpdate = onUpdate
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        timerTask?.cancel()
    }

    public func start() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        Task { [weak self] in
            guard let self else { return }
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .notDetermined {
                _ = try? await self.eventStore.requestFullAccessToEvents()
            }
            self.refresh()
            self.startGentleRefreshLoop()
        }
    }

    public func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        timerTask?.cancel()
        timerTask = nil
    }

    private func startGentleRefreshLoop() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    public func refresh(now: Date = .now) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            onUpdate(nil)
            return
        }

        let start = now.addingTimeInterval(-15 * 60)
        let end = now.addingTimeInterval(12 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        for event in events {
            let url = MeetingDetector.extractJoinURL(from: [
                event.url?.absoluteString,
                event.location,
                event.notes
            ])
            if let url {
                onUpdate(UpcomingMeeting(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Meeting",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    joinURL: url
                ))
                return
            }
        }
        onUpdate(nil)
    }
}
