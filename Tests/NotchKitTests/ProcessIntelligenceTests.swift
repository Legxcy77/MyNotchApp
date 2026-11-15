import Foundation
import Testing
@testable import NotchKit

@Suite struct ProcessIntelligenceTests {
    @Test func parsesPsOutputAndEnrichesDevServersWithProjectAndParentPID() {
        let lsofSample = """
        p4821
        cnode
        n127.0.0.1:3000
        p9100
        cdotnet
        n*:5000
        """
        let servers = LsofParser.parse(lsofSample, excludedPID: 99999, excludedPort: 7777)

        let psSample = """
         4821  1200 pawalit S    04:12 /usr/local/bin/node /Users/pawalit/Workspace/my-nextjs-app/node_modules/.bin/next dev
         9100     1 root    S    12:00 /usr/local/share/dotnet/dotnet /srv/api/Orders.Api.dll
        """
        let psMap = PsOutputParser.parse(psSample)
        #expect(psMap[4821]?.parentPID == 1200)
        #expect(psMap[4821]?.user == "pawalit")
        #expect(psMap[9100]?.user == "root")

        let enriched = ProcessInspector.enrich(servers: servers, psMap: psMap, currentUser: "pawalit")
        #expect(enriched.count == 2)

        let node = enriched[0]
        #expect(node.pid == 4821)
        #expect(node.localAddress == "127.0.0.1:3000")
        #expect(node.parentPID == 1200)
        #expect(node.associatedProject == "my-nextjs-app")
        #expect(!node.isProtected)

        let rootDotnet = enriched[1]
        #expect(rootDotnet.pid == 9100)
        #expect(rootDotnet.isProtected)
    }

    @Test func handlesDisappearedProcessAndUnknownProcessSafely() {
        let servers = [
            DevServer(pid: 777, processName: "unknown", port: 8080, label: "unknown"),
            DevServer(pid: 888, processName: "vite", port: 5173, label: "Vite")
        ]
        // PID 777 disappeared before `ps` ran; PID 888 exists
        let psSample = """
          888   500 pawalit S    00:45 node /Users/pawalit/dev/shop-web/node_modules/.bin/vite
        """
        let psMap = PsOutputParser.parse(psSample)
        let enriched = ProcessInspector.enrich(servers: servers, psMap: psMap, currentUser: "pawalit")

        #expect(enriched[0].isProtected) // unknown process must not be killable
        #expect(enriched[1].associatedProject == "shop-web")
        #expect(!enriched[1].isProtected)
    }

    @Test func detectsMultipleListenersOnSamePort() {
        let s1 = DevServer(pid: 101, processName: "node", port: 3000, label: "Node / Next")
        let s2 = DevServer(pid: 202, processName: "python3", port: 3000, label: "Python")
        let s3 = DevServer(pid: 303, processName: "vite", port: 5173, label: "Vite")

        let conflicts = ProcessInspector.detectPortConflicts([s1, s2, s3])
        #expect(conflicts.count == 1)
        #expect(conflicts[0].port == 3000)
        #expect(conflicts[0].servers.count == 2)
    }
}

