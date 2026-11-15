import Foundation
import Testing
@testable import NotchKit

@Suite
struct TextTransformerTests {
    @Test func transformsAndCountsText() {
        let stats = TextTransformer.stats(for: "hello   world\nline two")
        #expect(stats.words == 4)
        #expect(stats.lines == 2)
        #expect(stats.characters == 22)

        #expect(TextTransformer.transform("hello world", .uppercase) == "HELLO WORLD")
        #expect(TextTransformer.transform("HELLO", .lowercase) == "hello")
        #expect(TextTransformer.transform("  hello   world \n ", .trimAndCollapse) == "hello world")
        #expect(TextTransformer.transform("{\"a\":1}", .prettyJSON) == "{\n  \"a\" : 1\n}")
    }
}

