import Foundation
import Testing
@testable import NotchKit

@Suite struct ScreenshotShelfTests {
    @Test func recognizesEnglishAndThaiScreenshotsAndIgnoresTempFiles() {
        #expect(ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/Screenshot 2026-11-15 at 08.46.00.png")))
        #expect(ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/Screen Shot 2026-11-15.jpg")))
        #expect(ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/ภาพถ่ายหน้าจอ 2569-11-15 เวลา 08.25.54.png")))
        #expect(!ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/.Screenshot 2026-11-15.png")))
        #expect(!ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/notes.txt")))
        #expect(!ScreenshotDetector.isScreenshotFile(URL(fileURLWithPath: "/Users/me/Desktop/avatar.png")))
    }

    @Test func diffsOnlyNewlyAppearedScreenshots() {
        let old = URL(fileURLWithPath: "/tmp/Screenshot 1.png")
        let fresh = URL(fileURLWithPath: "/tmp/Screenshot 2.png")
        let nonShot = URL(fileURLWithPath: "/tmp/other.png")

        let added = ScreenshotDetector.diffNewScreenshots(
            previous: [old.standardizedFileURL],
            current: [old, fresh, nonShot]
        )
        #expect(added == [fresh.standardizedFileURL])
    }
}

