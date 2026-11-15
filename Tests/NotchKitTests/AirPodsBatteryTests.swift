import Foundation
import Testing
@testable import NotchKit

@Suite("AirPodsBatteryTests")
struct AirPodsBatteryTests {
    @Test("Parses SPBluetoothDataType JSON for AirPods Pro L/R/Case and single-battery headphones")
    func parsesBluetoothJSON() throws {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Pawalit’s AirPods Pro": {
                    "device_address": "AA:BB:CC:DD:EE:FF",
                    "device_minorType": "Headphones",
                    "device_batteryLevelLeft": "90%",
                    "device_batteryLevelRight": "85%",
                    "device_batteryLevelCase": "100%"
                  }
                },
                {
                  "Sony WH-1000XM5": {
                    "device_address": "11:22:33:44:55:66",
                    "device_minorType": "Headphones",
                    "device_batteryLevelMain": "72%"
                  }
                }
              ]
            }
          ]
        }
        """

        let devices = AirPodsBatteryParser.parse(Data(json.utf8))
        #expect(devices.count == 2)

        let airpods = try #require(devices.first(where: { $0.deviceName.contains("AirPods Pro") }))
        #expect(airpods.leftPercent == 90)
        #expect(airpods.rightPercent == 85)
        #expect(airpods.casePercent == 100)
        #expect(airpods.symbolName == "airpodspro")
        #expect(airpods.summaryText == "L 90% · R 85% · Case 100%")

        let sony = try #require(devices.first(where: { $0.deviceName.contains("Sony") }))
        #expect(sony.singlePercent == 72)
        #expect(sony.symbolName == "headphones")
        #expect(sony.summaryText == "Battery 72%")
    }

    @Test("Ignores devices without battery metadata")
    func ignoresDevicesWithoutBattery() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Magic Trackpad": {
                    "device_minorType": "Trackpad"
                  }
                }
              ]
            }
          ]
        }
        """
        let devices = AirPodsBatteryParser.parse(Data(json.utf8))
        #expect(devices.isEmpty)
    }
}

