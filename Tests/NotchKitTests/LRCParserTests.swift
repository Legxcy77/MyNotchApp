import Foundation
import Testing
@testable import NotchKit

@Suite
struct LRCParserTests {
    @Test func parsesMetadataMultiTimestampsOffsetsAndBlankLines() {
        let raw = """
        [ti:Midnight City]
        [ar:M83]
        [al:Hurry Up, We're Dreaming]
        [by:lrclib]
        [offset:500]

        [00:05.00]Waiting in a car
        [00:10.250][00:30.50]Waiting for a ride in the dark

        [00:15.00]
        [00:20]The night city grows
        """

        let doc = LRCParser.parse(raw)
        #expect(doc.title == "Midnight City")
        #expect(doc.artist == "M83")
        #expect(doc.album == "Hurry Up, We're Dreaming")
        #expect(abs(doc.offset - 0.5) < 0.001)

        // Blank lines and empty timestamped lines are omitted; multi-timestamp line expands and sorts.
        #expect(doc.lines.count == 4)
        #expect(doc.lines.map(\.text) == [
            "Waiting in a car",
            "Waiting for a ride in the dark",
            "The night city grows",
            "Waiting for a ride in the dark"
        ])
        #expect(abs(doc.lines[0].time - 5.5) < 0.001)
        #expect(abs(doc.lines[1].time - 10.75) < 0.001)
        #expect(abs(doc.lines[2].time - 20.5) < 0.001)
        #expect(abs(doc.lines[3].time - 31.0) < 0.001)
    }

    @Test func binarySearchesCurrentLine() {
        let raw = """
        [00:02.00]Line 0
        [00:05.00]Line 1
        [00:08.50]Line 2
        [00:12.00]Line 3
        """
        let doc = LRCParser.parse(raw)

        #expect(doc.currentLineIndex(at: 0.0) == nil)
        #expect(doc.currentLineIndex(at: 1.99) == nil)
        #expect(doc.currentLineIndex(at: 2.0) == 0)
        #expect(doc.currentLineIndex(at: 4.9) == 0)
        #expect(doc.currentLineIndex(at: 5.0) == 1)
        #expect(doc.currentLineIndex(at: 8.5) == 2)
        #expect(doc.currentLineIndex(at: 10.0) == 2)
        #expect(doc.currentLineIndex(at: 12.0) == 3)
        #expect(doc.currentLineIndex(at: 99.0) == 3)
    }
}

