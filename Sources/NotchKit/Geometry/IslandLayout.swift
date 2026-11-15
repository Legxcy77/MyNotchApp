import CoreGraphics

/// Single source of truth for island sizes, shared by the SwiftUI view and the hit-testing controller.
public enum IslandLayout {
    /// Fixed panel canvas: big enough for the largest state plus shadow. The panel never resizes.
    public static let panelSize = CGSize(width: 760, height: 340)
    public static let expandedSize = CGSize(width: 560, height: 200)
    public static let toastBodyHeight: CGFloat = 54
    public static let fileDropHeight: CGFloat = 120

    public static let earWidth: CGFloat = 36

    public static func size(for mode: NotchMode, geometry g: NotchGeometry, hasActiveAgents: Bool = false) -> CGSize {
        switch mode {
        case .collapsed:
            guard hasActiveAgents else { return g.baseSize }
            return CGSize(width: g.baseSize.width + earWidth * 2, height: g.baseSize.height)
        case .expanded:
            return CGSize(width: max(expandedSize.width, g.baseSize.width + 200),
                          height: g.cameraClearance + expandedSize.height)
        case .toast:
            return CGSize(width: max(360, g.baseSize.width + 220),
                          height: g.cameraClearance + toastBodyHeight)
        case .fileDrop:
            return CGSize(width: max(440, g.baseSize.width + 240),
                          height: g.cameraClearance + fileDropHeight)
        }
    }

    public struct Radii: Equatable, Sendable {
        public var top: CGFloat
        public var bottom: CGFloat
    }

    public static func radii(for mode: NotchMode, geometry g: NotchGeometry) -> Radii {
        let bottom: CGFloat
        switch mode {
        case .collapsed: bottom = g.kind == .hardware ? 10 : g.baseSize.height / 2
        case .toast: bottom = 22
        case .expanded, .fileDrop: bottom = 28
        }
        // Hardware: flush with the bezel, so square top. Floating: a free-standing pill.
        let top: CGFloat = g.kind == .hardware ? 0 : (mode == .collapsed ? bottom : 18)
        return Radii(top: top, bottom: bottom)
    }

    /// Rect that counts as "hovering the island". Collapsed gets a forgiving activation zone,
    /// and it always extends to the very top edge so flicking the cursor up works.
    public static func hitRect(for mode: NotchMode, geometry g: NotchGeometry, hasActiveAgents: Bool = false) -> CGRect {
        var r = g.islandRect(size: size(for: mode, geometry: g, hasActiveAgents: hasActiveAgents))
        r.size.height += g.topInset
        if mode == .collapsed { r = r.insetBy(dx: -14, dy: -6) }
        return r
    }
}

