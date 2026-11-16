import CoreGraphics
import SwiftUI

/// Single source of truth for island sizes, shared by the SwiftUI view and the hit-testing controller.
public enum IslandLayout {
    /// Fixed panel canvas: big enough for the largest state plus shadow. The panel never resizes.
    public static let panelSize = CGSize(width: 760, height: 340)
    public static let expandedSize = CGSize(width: 620, height: 248)
    public static let toastBodyHeight: CGFloat = 54
    public static let fileDropHeight: CGFloat = 120

    public static let earWidth: CGFloat = 36
    public static let faceEarWidth: CGFloat = 108
    public static let cockpitEarWidth: CGFloat = 152
    public static let cockpitDetailHeight: CGFloat = 22

    public static func size(
        for mode: NotchMode,
        geometry g: NotchGeometry,
        hasActiveAgents: Bool = false,
        isFaceScanning: Bool = false,
        hasCockpitSignal: Bool = false,
        hasCockpitDetail: Bool = false
    ) -> CGSize {
        switch mode {
        case .collapsed:
            if isFaceScanning {
                return CGSize(width: g.baseSize.width + faceEarWidth * 2, height: g.baseSize.height)
            }
            if hasCockpitSignal {
                let extraH: CGFloat = hasCockpitDetail ? cockpitDetailHeight : 0
                return CGSize(width: g.baseSize.width + cockpitEarWidth * 2, height: g.baseSize.height + extraH)
            }
            guard hasActiveAgents else { return g.baseSize }
            return CGSize(width: g.baseSize.width + earWidth * 2, height: g.baseSize.height)
        case .expanded:
            return CGSize(width: max(expandedSize.width, g.baseSize.width + 200),
                          height: g.cameraClearance + expandedSize.height)
        case .clipboard, .commandPalette, .quickAI:
            return CGSize(width: max(expandedSize.width, g.baseSize.width + 200),
                          height: g.cameraClearance + 250)
        case .errorLens:
            return CGSize(width: max(600, g.baseSize.width + 240),
                          height: g.cameraClearance + 250)
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
        case .expanded, .fileDrop, .clipboard, .commandPalette, .quickAI, .errorLens: bottom = 28
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

/// Smooth Dynamic Island silhouette with optional concave top Bezier ears for hardware notches.
public struct NotchIslandShape: Shape, Sendable {
    public var topEarRadius: CGFloat
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public init(topEarRadius: CGFloat, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topEarRadius = topEarRadius
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(topEarRadius, AnimatablePair(topCornerRadius, bottomCornerRadius)) }
        set {
            topEarRadius = newValue.first
            topCornerRadius = newValue.second.first
            bottomCornerRadius = newValue.second.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        guard topEarRadius > 0.5 else {
            return UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            ).path(in: rect)
        }

        let ear = min(topEarRadius, rect.height * 0.25)
        let br = min(bottomCornerRadius, min(rect.width * 0.5, rect.height - ear))

        var p = Path()
        // Start at top-left outer ear tip, curving smoothly inward & down
        p.move(to: CGPoint(x: rect.minX - ear, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + ear),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - br))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + br, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - br, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + ear))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX + ear, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

public enum SwipeDirection: Equatable, Sendable {
    case up, down, left, right
}

public enum SwipePhase: Equatable, Sendable {
    case began, changed, ended, momentum
}

/// Pure state machine for trackpad two-finger swipe gestures over the Notch.
public struct SwipeGestureRecognizer: Sendable {
    public let threshold: CGFloat
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var hasTriggered = false

    public init(threshold: CGFloat = 28) {
        self.threshold = threshold
    }

    public mutating func ingest(deltaX: CGFloat, deltaY: CGFloat, phase: SwipePhase) -> SwipeDirection? {
        switch phase {
        case .momentum:
            return nil
        case .ended:
            accumulatedX = 0
            accumulatedY = 0
            hasTriggered = false
            return nil
        case .began:
            accumulatedX = 0
            accumulatedY = 0
            hasTriggered = false
        case .changed:
            break
        }

        guard !hasTriggered else { return nil }
        accumulatedX += deltaX
        accumulatedY += deltaY

        if abs(accumulatedY) >= abs(accumulatedX), abs(accumulatedY) >= threshold {
            hasTriggered = true
            // macOS natural scroll/trackpad: negative deltaY = fingers swipe down
            return accumulatedY < 0 ? .down : .up
        }
        if abs(accumulatedX) > abs(accumulatedY), abs(accumulatedX) >= threshold {
            hasTriggered = true
            return accumulatedX < 0 ? .left : .right
        }
        return nil
    }
}

