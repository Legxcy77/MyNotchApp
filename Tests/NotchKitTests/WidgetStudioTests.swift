import Foundation
import Testing
@testable import NotchKit

@Suite("WidgetStudioTests")
struct WidgetStudioTests {
    @MainActor
    @Test("NotchWidgetConfig defaults enable core widgets and keep walkAwayAutoLock opt-in")
    func defaultValuesAndOptIn() {
        let suiteName = "com.pawalit.MyNotchApp.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let config = NotchWidgetConfig(defaults: defaults)
        #expect(config.isEnabled(.earsNowPlaying) == true)
        #expect(config.isEnabled(.edgeGlow) == true)
        #expect(config.isEnabled(.hudVolumeBrightness) == true)
        #expect(config.isEnabled(.lockScreenAurora) == true)
        #expect(config.isEnabled(.walkAwayAutoLock) == false)
        #expect(config.walkAwayTimeoutSeconds == 30)
        #expect(config.auroraIntensity == 0.75)
        #expect(config.leftEarStat == .none)
        #expect(config.rightEarStat == .none)
        #expect(config.notchDisplayMode == .smartHover)
        #expect(config.islandOpacity == 1.0)
        #expect(config.scrollToSwitchTabs == true)
    }

    @MainActor
    @Test("NotchWidgetConfig persists toggles across instances and resets cleanly")
    func persistenceAndReset() {
        let suiteName = "com.pawalit.MyNotchApp.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NotchWidgetConfig(defaults: defaults)
        first.setEnabled(.earsNowPlaying, false)
        first.setEnabled(.walkAwayAutoLock, true)
        first.auroraIntensity = 0.4
        first.walkAwayTimeoutSeconds = 45
        first.leftEarStat = .cpu
        first.rightEarStat = .battery
        first.notchDisplayMode = .fixed
        first.islandOpacity = 0.85
        first.scrollToSwitchTabs = false

        let reloaded = NotchWidgetConfig(defaults: defaults)
        #expect(reloaded.isEnabled(.earsNowPlaying) == false)
        #expect(reloaded.isEnabled(.walkAwayAutoLock) == true)
        #expect(reloaded.auroraIntensity == 0.4)
        #expect(reloaded.walkAwayTimeoutSeconds == 45)
        #expect(reloaded.leftEarStat == .cpu)
        #expect(reloaded.rightEarStat == .battery)
        #expect(reloaded.notchDisplayMode == .fixed)
        #expect(reloaded.islandOpacity == 0.85)
        #expect(reloaded.scrollToSwitchTabs == false)

        reloaded.resetToDefaults()
        #expect(reloaded.isEnabled(.earsNowPlaying) == true)
        #expect(reloaded.isEnabled(.walkAwayAutoLock) == false)
        #expect(reloaded.auroraIntensity == 0.75)
        #expect(reloaded.walkAwayTimeoutSeconds == 30)
        #expect(reloaded.leftEarStat == .none)
        #expect(reloaded.rightEarStat == .none)
        #expect(reloaded.notchDisplayMode == .smartHover)
        #expect(reloaded.islandOpacity == 1.0)
        #expect(reloaded.scrollToSwitchTabs == true)
    }

    @Test("Every WidgetID belongs to a category and has metadata")
    func allWidgetsHaveMetadata() {
        for widget in WidgetID.allCases {
            #expect(!widget.title.isEmpty)
            #expect(!widget.subtitle.isEmpty)
            #expect(!widget.symbol.isEmpty)
        }
        #expect(WidgetCategory.allCases.count == 4)
    }

    @Test("EarStatFormatter formats CPU, RAM, Battery, and Time cleanly")
    func formatsEarStats() {
        let sample = SystemPulseSample(cpuPercent: 24.4, ramUsedGB: 8, ramTotalGB: 16)
        #expect(EarStatFormatter.format(kind: .none, pulse: sample) == nil)
        #expect(EarStatFormatter.format(kind: .cpu, pulse: sample)?.text == "24%")
        #expect(EarStatFormatter.format(kind: .ram, pulse: sample)?.text == "50%")
        #expect(EarStatFormatter.format(kind: .battery, pulse: sample, batteryPercent: 88)?.text == "88%")
    }
}

