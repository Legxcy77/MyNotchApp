import Foundation
import Testing
@testable import NotchKit

@Suite("BentoLayoutTests")
struct BentoLayoutTests {
    @Test
    func packsMixedSmallMediumLargeAndFullTilesIntoRows() {
        let items = [
            BentoPlacement(kind: .databaseMigrations, size: .small), // 2
            BentoPlacement(kind: .changeImpact, size: .large),       // 4 -> row 1 = 6
            BentoPlacement(kind: .releaseReadiness, size: .medium),  // 3
            BentoPlacement(kind: .ciWatchtower, size: .small),       // 2 -> row 2 = 5
            BentoPlacement(kind: .devServers, size: .full),          // 6 -> wraps to row 3
            BentoPlacement(kind: .quickTools, size: .medium)         // 3 -> wraps to row 4
        ]

        let rows = BentoLayoutEngine.packRows(items)
        #expect(rows.count == 4)
        #expect(rows[0].map(\.kind) == [.databaseMigrations, .changeImpact])
        #expect(rows[1].map(\.kind) == [.releaseReadiness, .ciWatchtower])
        #expect(rows[2].map(\.kind) == [.devServers])
        #expect(rows[3].map(\.kind) == [.quickTools])
    }

    @Test
    @MainActor
    func widgetConfigPersistsAddReplaceResizeMoveRemoveAndReset() {
        let suiteName = "BentoLayoutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let config = NotchWidgetConfig(defaults: defaults)
        #expect(config.overviewLayout.map(\.kind) == [.systemAndGit, .quickTools, .devServers])

        config.addBentoTile(.releaseReadiness, size: .small)
        #expect(config.overviewLayout.count == 4)
        let addedID = config.overviewLayout[3].id

        config.resizeBentoTile(id: addedID, to: .large)
        #expect(config.overviewLayout[3].size == .large)

        config.replaceBentoTile(id: addedID, with: .dockerHealth)
        #expect(config.overviewLayout[3].kind == .dockerHealth)
        #expect(config.overviewLayout[3].size == .large)

        config.moveBentoTile(id: addedID, offset: -2)
        #expect(config.overviewLayout[1].id == addedID)

        // Reload from UserDefaults to verify persistence
        let reloaded = NotchWidgetConfig(defaults: defaults)
        #expect(reloaded.overviewLayout == config.overviewLayout)

        reloaded.removeBentoTile(id: addedID)
        #expect(reloaded.overviewLayout.count == 3)

        reloaded.resetToDefaults()
        #expect(reloaded.overviewLayout.map(\.kind) == [.systemAndGit, .quickTools, .devServers])
    }
}
