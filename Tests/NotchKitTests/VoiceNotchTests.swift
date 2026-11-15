import Foundation
import Testing
@testable import NotchKit

@Suite("VoiceNotchTests")
struct VoiceNotchTests {
    @Test("VoiceCommandPromptBuilder combines spoken query and screen context cleanly")
    func buildsPromptWithAndWithoutScreenContext() {
        let withContext = VoiceCommandPromptBuilder.build(
            transcript: "ดู error นี้ให้หน่อย",
            screenContext: "error: cannot convert value of type 'Int' to 'String'"
        )
        #expect(withContext.contains("ดู error นี้ให้หน่อย"))
        #expect(withContext.contains("cannot convert value"))

        let withoutContext = VoiceCommandPromptBuilder.build(
            transcript: "สรุปวิธีใช้ git rebase",
            screenContext: nil
        )
        #expect(withoutContext.contains("สรุปวิธีใช้ git rebase"))
        #expect(!withoutContext.contains("Screen context"))
    }

    @Test("VoiceCommandPromptBuilder truncates oversized screen context")
    func truncatesOversizedContext() {
        let huge = String(repeating: "x", count: 5000)
        let built = VoiceCommandPromptBuilder.build(transcript: "help", screenContext: huge)
        #expect(built.count < 2600)
    }
}

