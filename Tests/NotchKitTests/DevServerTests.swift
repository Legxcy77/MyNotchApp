import Foundation
import Testing
@testable import NotchKit

@Suite struct DevServerTests {
    @Test func parsesLsofOutputDeduplicatesDualStackAndFiltersSelf() {
        let sample = """
        p1234
        cnode
        n127.0.0.1:5173
        n[::1]:5173
        p5678
        cdotnet
        n*:5000
        p9999
        cMyNotchApp
        n127.0.0.1:7777
        p4321
        cpython3
        n[::]:8000
        """

        let servers = LsofParser.parse(sample, excludedPID: 9999, excludedPort: 7777)
        #expect(servers.count == 3)

        #expect(servers[0].pid == 5678)
        #expect(servers[0].port == 5000)
        #expect(servers[0].processName == "dotnet")

        #expect(servers[1].pid == 1234)
        #expect(servers[1].port == 5173)
        #expect(servers[1].label == "Vite")

        #expect(servers[2].pid == 4321)
        #expect(servers[2].port == 8000)
        #expect(servers[2].processName == "python3")
    }

    @Test func ignoresMalformedLines() {
        let sample = """
        pnotanumber
        cnode
        n*:3000
        p100
        cnext-server
        n127.0.0.1:notaport
        n*:3000
        """

        let servers = LsofParser.parse(sample, excludedPID: 1, excludedPort: 7777)
        #expect(servers.count == 1)
        #expect(servers[0].pid == 100)
        #expect(servers[0].port == 3000)
    }
}

