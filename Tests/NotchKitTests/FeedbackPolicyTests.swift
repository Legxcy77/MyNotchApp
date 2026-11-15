import Testing
@testable import NotchKit

@Suite
struct FeedbackPolicyTests {
    @Test func hapticTriggersOnlyOnHighAndCriticalPriority() {
        #expect(FeedbackPolicy.shouldTriggerHaptic(for: Toast(title: "Low", priority: .low)) == false)
        #expect(FeedbackPolicy.shouldTriggerHaptic(for: Toast(title: "Normal", priority: .normal)) == false)
        #expect(FeedbackPolicy.shouldTriggerHaptic(for: Toast(title: "High", priority: .high)) == true)
        #expect(FeedbackPolicy.shouldTriggerHaptic(for: Toast(title: "Critical", priority: .critical)) == true)
    }

    @Test func mapsSubtleSoundPerTint() {
        #expect(FeedbackPolicy.soundName(for: .neutral) == nil)
        #expect(FeedbackPolicy.soundName(for: .success) == "Glass")
        #expect(FeedbackPolicy.soundName(for: .failure) == "Basso")
        #expect(FeedbackPolicy.soundName(for: .waiting) == "Ping")
        #expect(FeedbackPolicy.soundName(for: .info) == "Pop")
    }
}
