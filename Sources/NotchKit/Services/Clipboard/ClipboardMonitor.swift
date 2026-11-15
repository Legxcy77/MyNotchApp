import AppKit
import ApplicationServices

@MainActor
public final class ClipboardMonitor {
    private let onRecord: @MainActor (ClipboardItem.Content, Date) -> Void
    private var pollTask: Task<Void, Never>?
    private var lastChangeCount: Int

    public init(onRecord: @escaping @MainActor (ClipboardItem.Content, Date) -> Void) {
        self.onRecord = onRecord
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled, let self {
                self.checkPasteboard()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func writeAndPaste(_ item: ClipboardItem, targetApp: NSRunningApplication?) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let str):
            pb.setString(str, forType: .string)
        case .image(let data):
            pb.setData(data, forType: .png)
        }
        lastChangeCount = pb.changeCount

        if let targetApp {
            targetApp.activate()
        }

        let trusted = AXIsProcessTrusted()
        guard trusted else {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let opts = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            return false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            Self.synthesizeCommandV()
        }
        return true
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let typeNames = (pb.types ?? []).map(\.rawValue)
        guard !ClipboardHistory.shouldIgnore(pasteboardTypes: typeNames) else { return }

        if let str = pb.string(forType: .string) {
            onRecord(.text(str), .now)
            return
        }

        if let png = pb.data(forType: .png), png.count <= 10 * 1024 * 1024 {
            onRecord(.image(png), .now)
            return
        }

        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]),
           png.count <= 10 * 1024 * 1024 {
            onRecord(.image(png), .now)
        }
    }

    private static func synthesizeCommandV() {
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

