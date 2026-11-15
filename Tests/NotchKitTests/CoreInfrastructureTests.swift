import Foundation
import Testing
@testable import NotchKit

@Suite("CoreInfrastructureTests")
struct CoreInfrastructureTests {
    @Test
    func islandLayoutSizesAndRadiiForHardwareAndFloating() {
        let hardware = NotchGeometry(
            kind: .hardware,
            baseSize: CGSize(width: 200, height: 32),
            midX: 756,
            screenTop: 982,
            topInset: 0
        )
        let floating = NotchGeometry(
            kind: .floating,
            baseSize: CGSize(width: 180, height: 28),
            midX: 960,
            screenTop: 1080,
            topInset: 8
        )

        #expect(IslandLayout.size(for: .collapsed, geometry: hardware) == hardware.baseSize)
        #expect(IslandLayout.size(for: .collapsed, geometry: hardware, hasActiveAgents: true).width == 200 + IslandLayout.earWidth * 2)
        #expect(IslandLayout.size(for: .collapsed, geometry: hardware, isFaceScanning: true).width == 200 + IslandLayout.faceEarWidth * 2)

        #expect(IslandLayout.size(for: .expanded, geometry: hardware).height == hardware.cameraClearance + IslandLayout.expandedSize.height)
        #expect(IslandLayout.size(for: .toast(Toast(title: "Hi")), geometry: hardware).height == hardware.cameraClearance + IslandLayout.toastBodyHeight)
        #expect(IslandLayout.size(for: .fileDrop, geometry: hardware).height == hardware.cameraClearance + IslandLayout.fileDropHeight)
        #expect(IslandLayout.size(for: .errorLens(title: "Err", log: "Line 1"), geometry: hardware).height == hardware.cameraClearance + 250)
        #expect(IslandLayout.size(for: .quickAI, geometry: floating).height == floating.cameraClearance + 250)

        let hwCollapsedRadii = IslandLayout.radii(for: .collapsed, geometry: hardware)
        #expect(hwCollapsedRadii == IslandLayout.Radii(top: 0, bottom: 10))

        let floatCollapsedRadii = IslandLayout.radii(for: .collapsed, geometry: floating)
        #expect(floatCollapsedRadii == IslandLayout.Radii(top: 14, bottom: 14))

        let floatExpandedRadii = IslandLayout.radii(for: .expanded, geometry: floating)
        #expect(floatExpandedRadii == IslandLayout.Radii(top: 18, bottom: 28))
    }

    @Test
    func tokenStoreCreatesPersistsAndRegeneratesEmptyToken() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mynotch-token-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tokenURL = dir.appendingPathComponent("token")
        let first = try TokenStore.loadOrCreate(at: tokenURL)
        #expect(first.count == 48)
        #expect(first.allSatisfy { $0.isHexDigit })

        let second = try TokenStore.loadOrCreate(at: tokenURL)
        #expect(second == first)

        let attrs = try FileManager.default.attributesOfItem(atPath: tokenURL.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue
        #expect(perms == 0o600)

        try "   \n".write(to: tokenURL, atomically: true, encoding: .utf8)
        let regenerated = try TokenStore.loadOrCreate(at: tokenURL)
        #expect(regenerated.count == 48)
        #expect(regenerated != first)
    }
}
