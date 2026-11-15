import Foundation
import Testing
@testable import NotchKit

@Suite("DockerGlanceTests")
struct DockerGlanceTests {
    @Test("DockerContainerParser parses Docker Engine /containers/json payload")
    func parsesDockerContainersJSON() throws {
        let json = """
        [
          {
            "Id": "abc1234567890def",
            "Names": ["/postgres-dev"],
            "Image": "postgres:16-alpine",
            "State": "running",
            "Status": "Up 3 hours",
            "Ports": [
              { "IP": "0.0.0.0", "PrivatePort": 5432, "PublicPort": 5432, "Type": "tcp" },
              { "IP": "::", "PrivatePort": 5432, "PublicPort": 5432, "Type": "tcp" }
            ]
          },
          {
            "Id": "fff999888777666",
            "Names": ["/redis-cache"],
            "Image": "redis:7",
            "State": "running",
            "Status": "Up 12 minutes",
            "Ports": [
              { "PrivatePort": 6379, "Type": "tcp" }
            ]
          }
        ]
        """

        let containers = DockerContainerParser.parse(Data(json.utf8))
        #expect(containers.count == 2)

        let pg = containers[0]
        #expect(pg.id == "abc1234567890def")
        #expect(pg.name == "postgres-dev")
        #expect(pg.image == "postgres:16-alpine")
        #expect(pg.state == "running")
        #expect(pg.status == "Up 3 hours")
        #expect(pg.portsSummary == "5432→5432")

        let redis = containers[1]
        #expect(redis.name == "redis-cache")
        #expect(redis.portsSummary == "6379")
    }

    @Test("DockerGlanceMonitor extracts HTTP body from raw socket response")
    func extractsHTTPBody() {
        let raw = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n[{\"Id\":\"1\",\"Names\":[\"/api\"],\"Image\":\"node:22\",\"State\":\"running\",\"Status\":\"Up 1m\",\"Ports\":[]}]"
        let body = DockerContainerParser.extractHTTPBody(from: Data(raw.utf8))
        let parsed = DockerContainerParser.parse(body ?? Data())
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "api")
    }
}

