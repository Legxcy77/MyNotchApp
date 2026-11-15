import AppKit
import Foundation

public enum FeedbackPolicy {
    public static func shouldTriggerHaptic(for toast: Toast) -> Bool {
        toast.priority >= .high
    }

    public static func soundName(for tint: Toast.Tint) -> String? {
        switch tint {
        case .neutral: nil
        case .success: "Glass"
        case .failure: "Basso"
        case .waiting: "Ping"
        case .info: "Pop"
        }
    }
}

@MainActor
public final class FeedbackService {
    private static let soundEnabledKey = "notch.feedback.soundEnabled"
    private static let hapticEnabledKey = "notch.feedback.hapticEnabled"

    private let defaults: UserDefaults

    public var isSoundEnabled: Bool {
        get { defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.soundEnabledKey) }
    }

    public var isHapticEnabled: Bool {
        get { defaults.object(forKey: Self.hapticEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.hapticEnabledKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func play(for toast: Toast) {
        if isHapticEnabled && FeedbackPolicy.shouldTriggerHaptic(for: toast) {
            let pattern: NSHapticFeedbackManager.FeedbackPattern = toast.priority == .critical ? .levelChange : .generic
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        }

        if isSoundEnabled,
           let name = FeedbackPolicy.soundName(for: toast.tint),
           let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = 0.25
            sound.play()
        }
    }
}
