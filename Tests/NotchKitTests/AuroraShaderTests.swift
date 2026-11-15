import Foundation
import Testing
@testable import NotchKit

@Suite("AuroraShaderTests")
struct AuroraShaderTests {
    @Test("AuroraPalette maps NotchTint semantics to distinct RGB palettes")
    func mapsTintPalettes() {
        let ok = AuroraPalette.from(tint: .success)
        let fail = AuroraPalette.from(tint: .failure)
        let warn = AuroraPalette.from(tint: .waiting)
        let info = AuroraPalette.from(tint: .info)

        #expect(ok.primary.y > ok.primary.x)     // Green dominant
        #expect(fail.primary.x > fail.primary.y) // Red dominant
        #expect(warn.primary.x > warn.primary.z) // Orange/warm dominant
        #expect(info.primary.z >= info.primary.x) // Blue dominant
    }

    @Test("AuroraPalette falls back cleanly on invalid or empty image data")
    func invalidImageDataFallsBack() {
        let fallback = AuroraPalette.from(imageData: nil)
        let corrupt = AuroraPalette.from(imageData: Data([0x00, 0x01, 0x02]))
        #expect(fallback == .midnight)
        #expect(corrupt == .midnight)
    }
}
