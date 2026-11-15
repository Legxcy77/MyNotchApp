import AppKit
import Carbon
import Foundation

@MainActor
public final class KeyboardStatusMonitor {
    private var tISObserver: NSObjectProtocol?
    private var lastSourceID: String?
    private let onToast: @MainActor (Toast) -> Void

    public init(onToast: @escaping @MainActor (Toast) -> Void) {
        self.onToast = onToast
    }

    isolated deinit {
        if let tISObserver {
            DistributedNotificationCenter.default().removeObserver(tISObserver)
        }
    }

    public func start() {
        lastSourceID = currentInputSource().id

        tISObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInputSourceChanged()
            }
        }
    }

    public func stop() {
        if let tISObserver {
            DistributedNotificationCenter.default().removeObserver(tISObserver)
            self.tISObserver = nil
        }
    }

    private func handleInputSourceChanged() {
        let info = currentInputSource()
        guard info.id != lastSourceID else { return }
        lastSourceID = info.id
        onToast(Toast(
            key: "kbd:input",
            title: info.shortLabel,
            subtitle: info.name,
            symbol: "globe",
            tint: .neutral,
            priority: .low,
            duration: .seconds(1.2)
        ))
    }

    private func currentInputSource() -> (id: String, name: String, shortLabel: String) {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return ("", "Keyboard", "KB")
        }
        let id = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyInputSourceID)).takeUnretainedValue() as String
        let name = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyLocalizedName)).takeUnretainedValue() as String
        let lower = (id + " " + name).lowercased()
        let short: String
        if lower.contains("thai") || lower.contains("kedmanee") || lower.contains("pattachote") {
            short = "TH"
        } else if lower.contains("abc") || lower.contains("english") || lower.contains("u.s.") {
            short = "EN"
        } else {
            short = String(name.prefix(3)).uppercased()
        }
        return (id, name, short)
    }
}

