import Foundation
import Testing
@testable import NotchKit

@Suite("PowerSourceTests")
struct PowerSourceTests {
    @Test("PowerSourceParser extracts AC charging state, percentage, and adapter watts")
    func parsesACPowerAndWatts() {
        let desc: [String: Any] = [
            "Power Source State": "AC Power",
            "Is Charging": true,
            "Current Capacity": 84,
            "Max Capacity": 100,
        ]
        let snapshot = PowerSourceParser.parse(description: desc, adapterWatts: 67)
        #expect(snapshot == PowerSourceSnapshot(isACPower: true, isCharging: true, batteryPercent: 84, watts: 67))
    }

    @Test("PowerSourceParser handles Battery Power without adapter")
    func parsesBatteryPower() {
        let desc: [String: Any] = [
            "Power Source State": "Battery Power",
            "Is Charging": false,
            "Current Capacity": 52,
            "Max Capacity": 100,
        ]
        let snapshot = PowerSourceParser.parse(description: desc, adapterWatts: nil)
        #expect(snapshot == PowerSourceSnapshot(isACPower: false, isCharging: false, batteryPercent: 52, watts: nil))
    }
}

