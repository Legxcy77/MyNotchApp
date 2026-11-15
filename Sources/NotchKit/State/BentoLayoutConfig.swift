import Foundation

public enum BentoTileSize: String, CaseIterable, Identifiable, Codable, Sendable {
    case small
    case medium
    case large
    case full

    public var id: String { rawValue }

    /// Width in 6-column Bento units (2 = 1/3, 3 = 1/2, 4 = 2/3, 6 = full width).
    public var columnUnits: Int {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        case .full: return 6
        }
    }

    public var shortLabel: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .full: return "Full"
        }
    }
}

public enum BentoTileKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemAndGit
    case quickTools
    case devServers
    case nowPlaying
    case releaseReadiness
    case changeImpact
    case dockerHealth
    case ciWatchtower
    case databaseMigrations
    case securityAndEnv
    case agentConflicts
    case quickNotes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .systemAndGit: return "Workspace & Git"
        case .quickTools: return "Quick Launch"
        case .devServers: return "Dev Servers"
        case .nowPlaying: return "Now Playing"
        case .releaseReadiness: return "Release Gate"
        case .changeImpact: return "Change Impact"
        case .dockerHealth: return "Docker Health"
        case .ciWatchtower: return "CI Watchtower"
        case .databaseMigrations: return "DB Migrations"
        case .securityAndEnv: return "Security & Env"
        case .agentConflicts: return "Agents & Radar"
        case .quickNotes: return "Notes & Tasks"
        }
    }

    public var symbol: String {
        switch self {
        case .systemAndGit: return "cpu"
        case .quickTools: return "square.grid.2x2.fill"
        case .devServers: return "server.rack"
        case .nowPlaying: return "music.note"
        case .releaseReadiness: return "checkmark.seal.fill"
        case .changeImpact: return "waveform.path.ecg"
        case .dockerHealth: return "shippingbox.fill"
        case .ciWatchtower: return "arrow.triangle.2.circlepath.circle.fill"
        case .databaseMigrations: return "cylinder.split.1x2.fill"
        case .securityAndEnv: return "lock.shield.fill"
        case .agentConflicts: return "exclamationmark.2"
        case .quickNotes: return "checklist"
        }
    }

    public var defaultSize: BentoTileSize {
        switch self {
        case .devServers: return .full
        case .databaseMigrations: return .small
        default: return .medium
        }
    }
}

public struct BentoPlacement: Equatable, Identifiable, Codable, Sendable {
    public var id: UUID
    public var kind: BentoTileKind
    public var size: BentoTileSize

    public init(id: UUID = UUID(), kind: BentoTileKind, size: BentoTileSize? = nil) {
        self.id = id
        self.kind = kind
        self.size = size ?? kind.defaultSize
    }
}

public enum BentoLayoutEngine {
    public static let maxColumns = 6

    public static let defaultPlacements: [BentoPlacement] = [
        BentoPlacement(kind: .systemAndGit, size: .medium),
        BentoPlacement(kind: .quickTools, size: .medium),
        BentoPlacement(kind: .devServers, size: .full)
    ]

    /// Packs variable-sized Bento placements into 6-unit rows without fixed slot locks.
    public static func packRows(_ placements: [BentoPlacement]) -> [[BentoPlacement]] {
        var rows: [[BentoPlacement]] = []
        var currentRow: [BentoPlacement] = []
        var currentUnits = 0

        for item in placements {
            let units = min(maxColumns, max(1, item.size.columnUnits))
            if currentUnits + units > maxColumns, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [item]
                currentUnits = units
            } else {
                currentRow.append(item)
                currentUnits += units
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
