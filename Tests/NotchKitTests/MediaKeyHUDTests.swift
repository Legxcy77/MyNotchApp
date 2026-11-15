import Foundation
import Testing
@testable import NotchKit

@Suite("MediaKeyHUDTests")
struct MediaKeyHUDTests {
    @Test("Decodes NX_KEYTYPE volume, mute, brightness, and keyboard backlight systemDefined data1")
    func decodesSystemDefinedMediaKeys() {
        // keyCode in upper 16 bits, keyDown = 0x0A in bits 8..15
        func makeData1(keyCode: Int, isKeyDown: Bool) -> Int {
            let state = isKeyDown ? 0x0A00 : 0x0B00
            return (keyCode << 16) | state
        }

        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 0, isKeyDown: true)) == .volumeUp)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 1, isKeyDown: true)) == .volumeDown)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 7, isKeyDown: true)) == .mute)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 2, isKeyDown: true)) == .brightnessUp)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 3, isKeyDown: true)) == .brightnessDown)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 21, isKeyDown: true)) == .keyboardBrightnessUp)
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 22, isKeyDown: true)) == .keyboardBrightnessDown)

        // Key up (0x0B) and non-media subtypes are ignored
        #expect(MediaKeyEventDecoder.decode(subtype: 8, data1: makeData1(keyCode: 0, isKeyDown: false)) == nil)
        #expect(MediaKeyEventDecoder.decode(subtype: 7, data1: makeData1(keyCode: 0, isKeyDown: true)) == nil)
    }

    @Test("Builds volume symbol matching mute and level thresholds")
    func volumeSymbolSelection() {
        #expect(MediaKeyEventDecoder.volumeSymbol(level: 0.0, isMuted: true) == "speaker.slash.fill")
        #expect(MediaKeyEventDecoder.volumeSymbol(level: 0.0, isMuted: false) == "speaker.fill")
        #expect(MediaKeyEventDecoder.volumeSymbol(level: 0.25, isMuted: false) == "speaker.wave.1.fill")
        #expect(MediaKeyEventDecoder.volumeSymbol(level: 0.55, isMuted: false) == "speaker.wave.2.fill")
        #expect(MediaKeyEventDecoder.volumeSymbol(level: 0.90, isMuted: false) == "speaker.wave.3.fill")
    }
}

