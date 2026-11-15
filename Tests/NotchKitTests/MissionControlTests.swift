import Foundation
import Testing
@testable import NotchKit

@Suite("MissionControlTests")
struct MissionControlTests {
    @Test("TerminalTailBuffer keeps at most 5 lines and tracks last error")
    func tailBufferAndErrors() {
        var buffer = TerminalTailBuffer(capacity: 5)
        buffer.append("Building target NotchKit...")
        buffer.append("Compiling ToastView.swift")
        buffer.append("error: cannot find 'foo' in scope")
        buffer.append("Linking target NotchKit")
        buffer.append("line 5")
        buffer.append("line 6")

        #expect(buffer.lines.count == 5)
        #expect(buffer.lines.first == "Compiling ToastView.swift")
        #expect(buffer.lines.last == "line 6")
        #expect(buffer.lastErrorLine == "error: cannot find 'foo' in scope")
    }

    @Test("MissionControlSummary formats ticker with elapsed MM:SS")
    func tickerFormatting() {
        #expect(MissionControlSummary.formatElapsed(4) == "00:04")
        #expect(MissionControlSummary.formatElapsed(75) == "01:15")
        #expect(MissionControlSummary.formattedTicker(title: "swift test", elapsedSeconds: 12) == "swift test · 00:12")
    }
}
