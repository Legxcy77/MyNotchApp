import Foundation
import Observation

public enum WidgetCategory: String, CaseIterable, Identifiable, Sendable {
    case ears = "Notch Ears"
    case bento = "Expanded Bento"
    case lockScreen = "Lock Screen"
    case alertsAndAI = "Alerts & AI"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .ears: return "rectangle.topthird.inset.filled"
        case .bento: return "square.grid.2x2.fill"
        case .lockScreen: return "lock.display"
        case .alertsAndAI: return "sparkles"
        }
    }
}

public enum EarStatKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case cpu
    case ram
    case battery
    case time

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Off"
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .battery: return "Battery"
        case .time: return "Time"
        }
    }

    public var symbol: String {
        switch self {
        case .none: return "minus.circle"
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .battery: return "battery.75percent"
        case .time: return "clock"
        }
    }
}

public enum NotchDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case smartHover = "Smart Hover"
    case fixed = "Fixed"

    public var id: String { rawValue }
}

public enum WidgetID: String, CaseIterable, Identifiable, Codable, Sendable {
    case earsNowPlaying
    case earsDevTicker
    case earsSystemStats
    case edgeGlow
    case bentoDevCockpit
    case bentoDockerGlance
    case bentoMissionControl
    case bentoSpatial3D
    case bentoCommandCenter
    case lockScreenCard
    case lockScreenAurora
    case walkAwayAutoLock
    case hudVolumeBrightness
    case hudAirPodsPopup
    case hudMagSafePopup
    case voiceAI

    public var id: String { rawValue }

    public var category: WidgetCategory {
        switch self {
        case .earsNowPlaying, .earsDevTicker, .earsSystemStats, .edgeGlow:
            return .ears
        case .bentoDevCockpit, .bentoDockerGlance, .bentoMissionControl, .bentoSpatial3D, .bentoCommandCenter:
            return .bento
        case .lockScreenCard, .lockScreenAurora, .walkAwayAutoLock:
            return .lockScreen
        case .hudVolumeBrightness, .hudAirPodsPopup, .hudMagSafePopup, .voiceAI:
            return .alertsAndAI
        }
    }

    public var title: String {
        switch self {
        case .earsNowPlaying: return "Now Playing Ears"
        case .earsDevTicker: return "Dev & AI Live Ticker"
        case .earsSystemStats: return "Ear Status Pills"
        case .edgeGlow: return "Dynamic Edge Glow"
        case .bentoDevCockpit: return "Dev Servers & Git"
        case .bentoDockerGlance: return "Docker Glance"
        case .bentoMissionControl: return "Live Terminal Tail"
        case .bentoSpatial3D: return "3D Device Showcase"
        case .bentoCommandCenter: return "Scroll & Smart Mode"
        case .lockScreenCard: return "Lock Screen Music"
        case .lockScreenAurora: return "Liquid Aurora Shader"
        case .walkAwayAutoLock: return "Walk-Away Auto-Lock"
        case .hudVolumeBrightness: return "Volume & Brightness HUD"
        case .hudAirPodsPopup: return "AirPods 3D Pop-up"
        case .hudMagSafePopup: return "MagSafe Power Pop-up"
        case .voiceAI: return "Voice-to-Notch AI"
        }
    }

    public var subtitle: String {
        switch self {
        case .earsNowPlaying: return "ปกเพลงและคลื่นเสียงข้างรอยบาก"
        case .earsDevTicker: return "สถานะ AI Agent และตัวจับเวลา Build"
        case .earsSystemStats: return "เลือกแสดง CPU / RAM / แบต / เวลา บนหูซ้าย-ขวา"
        case .edgeGlow: return "แสงเรืองขอบ Notch ตามสถานะงาน/เพลง"
        case .bentoDevCockpit: return "ดูพอร์ต Dev Server และสถานะ Git"
        case .bentoDockerGlance: return "จัดการ Docker Container & Tail Logs"
        case .bentoMissionControl: return "Log 5 บรรทัดล่าสุดแบบ Real-time"
        case .bentoSpatial3D: return "แสดงโมเดล 3D ของอุปกรณ์และแบตเตอรี่"
        case .bentoCommandCenter: return "Scroll สลับแท็บ + โหมด Smart/Fixed + Opacity"
        case .lockScreenCard: return "การ์ดเพลง + เนื้อเพลงบนหน้าจอล็อก"
        case .lockScreenAurora: return "พื้นหลัง Metal Aurora ดูดสีจากปกเพลง"
        case .walkAwayAutoLock: return "ล็อกจออัตโนมัติเมื่อลุกออกจากหน้าจอ"
        case .hudVolumeBrightness: return "แถบปรับเสียง/แสงแทน OSD ของระบบ"
        case .hudAirPodsPopup: return "แจ้งเตือน AirPods 3D พร้อมแบต L/R/Case"
        case .hudMagSafePopup: return "แจ้งเตือนเสียบชาร์จพร้อมกำลังไฟ"
        case .voiceAI: return "พูดสั่งงาน AI พร้อมอ่านบริบทหน้าจอ"
        }
    }

    public var symbol: String {
        switch self {
        case .earsNowPlaying: return "music.note"
        case .earsDevTicker: return "hammer.fill"
        case .earsSystemStats: return "cpu"
        case .edgeGlow: return "light.beacon.max.fill"
        case .bentoDevCockpit: return "server.rack"
        case .bentoDockerGlance: return "shippingbox.fill"
        case .bentoMissionControl: return "terminal.fill"
        case .bentoSpatial3D: return "cube.transparent.fill"
        case .bentoCommandCenter: return "switch.2"
        case .lockScreenCard: return "music.note.house.fill"
        case .lockScreenAurora: return "wand.and.stars"
        case .walkAwayAutoLock: return "person.crop.circle.badge.clock"
        case .hudVolumeBrightness: return "speaker.wave.3.fill"
        case .hudAirPodsPopup: return "airpodspro"
        case .hudMagSafePopup: return "bolt.fill"
        case .voiceAI: return "waveform.circle.fill"
        }
    }

    public var defaultEnabled: Bool {
        switch self {
        case .walkAwayAutoLock:
            return false
        default:
            return true
        }
    }
}

@MainActor
@Observable
public final class NotchWidgetConfig {
    private let defaults: UserDefaults
    private var states: [WidgetID: Bool]

    public var auroraIntensity: Double {
        didSet {
            defaults.set(auroraIntensity, forKey: Keys.auroraIntensity)
        }
    }

    public var walkAwayTimeoutSeconds: Int {
        didSet {
            defaults.set(walkAwayTimeoutSeconds, forKey: Keys.walkAwayTimeoutSeconds)
        }
    }

    public var leftEarStat: EarStatKind {
        didSet {
            defaults.set(leftEarStat.rawValue, forKey: Keys.leftEarStat)
        }
    }

    public var rightEarStat: EarStatKind {
        didSet {
            defaults.set(rightEarStat.rawValue, forKey: Keys.rightEarStat)
        }
    }

    public var notchDisplayMode: NotchDisplayMode {
        didSet {
            defaults.set(notchDisplayMode.rawValue, forKey: Keys.notchDisplayMode)
        }
    }

    public var islandOpacity: Double {
        didSet {
            defaults.set(islandOpacity, forKey: Keys.islandOpacity)
        }
    }

    public var scrollToSwitchTabs: Bool {
        didSet {
            defaults.set(scrollToSwitchTabs, forKey: Keys.scrollToSwitchTabs)
        }
    }

    private enum Keys {
        static let prefix = "mynotch.widget."
        static let auroraIntensity = "mynotch.widget.auroraIntensity"
        static let walkAwayTimeoutSeconds = "mynotch.widget.walkAwayTimeoutSeconds"
        static let leftEarStat = "mynotch.widget.leftEarStat"
        static let rightEarStat = "mynotch.widget.rightEarStat"
        static let notchDisplayMode = "mynotch.widget.notchDisplayMode"
        static let islandOpacity = "mynotch.widget.islandOpacity"
        static let scrollToSwitchTabs = "mynotch.widget.scrollToSwitchTabs"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded: [WidgetID: Bool] = [:]
        for widget in WidgetID.allCases {
            let key = Keys.prefix + widget.rawValue
            if defaults.object(forKey: key) != nil {
                loaded[widget] = defaults.bool(forKey: key)
            } else {
                loaded[widget] = widget.defaultEnabled
            }
        }
        self.states = loaded
        self.auroraIntensity = defaults.object(forKey: Keys.auroraIntensity) != nil
            ? defaults.double(forKey: Keys.auroraIntensity)
            : 0.75
        let savedTimeout = defaults.integer(forKey: Keys.walkAwayTimeoutSeconds)
        self.walkAwayTimeoutSeconds = savedTimeout > 0 ? savedTimeout : 30
        self.leftEarStat = (defaults.string(forKey: Keys.leftEarStat).flatMap(EarStatKind.init)) ?? .none
        self.rightEarStat = (defaults.string(forKey: Keys.rightEarStat).flatMap(EarStatKind.init)) ?? .none
        self.notchDisplayMode = (defaults.string(forKey: Keys.notchDisplayMode).flatMap(NotchDisplayMode.init)) ?? .smartHover
        self.islandOpacity = defaults.object(forKey: Keys.islandOpacity) != nil
            ? defaults.double(forKey: Keys.islandOpacity)
            : 1.0
        self.scrollToSwitchTabs = defaults.object(forKey: Keys.scrollToSwitchTabs) != nil
            ? defaults.bool(forKey: Keys.scrollToSwitchTabs)
            : true
    }

    public func isEnabled(_ widget: WidgetID) -> Bool {
        states[widget] ?? widget.defaultEnabled
    }

    public func setEnabled(_ widget: WidgetID, _ enabled: Bool) {
        states[widget] = enabled
        defaults.set(enabled, forKey: Keys.prefix + widget.rawValue)
    }

    public func toggle(_ widget: WidgetID) {
        setEnabled(widget, !isEnabled(widget))
    }

    public func resetToDefaults() {
        for widget in WidgetID.allCases {
            defaults.removeObject(forKey: Keys.prefix + widget.rawValue)
            states[widget] = widget.defaultEnabled
        }
        auroraIntensity = 0.75
        walkAwayTimeoutSeconds = 30
        leftEarStat = .none
        rightEarStat = .none
        notchDisplayMode = .smartHover
        islandOpacity = 1.0
        scrollToSwitchTabs = true
    }
}

