import CoreGraphics

/// Raw, framework-free snapshot of an NSScreen so geometry stays pure and testable.
public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var safeAreaTop: CGFloat
    public var auxiliaryTopLeft: CGRect?
    public var auxiliaryTopRight: CGRect?

    public init(frame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect? = nil, auxiliaryTopRight: CGRect? = nil) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeft = auxiliaryTopLeft
        self.auxiliaryTopRight = auxiliaryTopRight
    }

    public var hasNotch: Bool {
        safeAreaTop > 0 && auxiliaryTopLeft != nil && auxiliaryTopRight != nil
    }
}

/// Where the island lives on a given screen, in AppKit (y-up) screen coordinates.
public struct NotchGeometry: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case hardware, floating }

    public var kind: Kind
    /// Physical notch size (hardware) or resting pill size (floating).
    public var baseSize: CGSize
    public var midX: CGFloat
    public var screenTop: CGFloat
    /// Gap between the screen's top edge and the island (0 when hugging a hardware notch).
    public var topInset: CGFloat

    /// Height reserved at the top of the island that must stay empty (camera housing).
    public var cameraClearance: CGFloat { kind == .hardware ? baseSize.height : 0 }

    public func islandRect(size: CGSize) -> CGRect {
        CGRect(x: midX - size.width / 2,
               y: screenTop - topInset - size.height,
               width: size.width,
               height: size.height)
    }
}

public enum ScreenGeometry {
    public static let floatingPillSize = CGSize(width: 190, height: 32)
    public static let floatingTopInset: CGFloat = 6

    public static func resolve(_ m: ScreenMetrics) -> NotchGeometry {
        if m.hasNotch, let left = m.auxiliaryTopLeft, let right = m.auxiliaryTopRight {
            // Width math only uses widths, so it's immune to whichever origin AppKit reports aux rects in.
            let notchWidth = m.frame.width - left.width - right.width
            if notchWidth > 0 {
                return NotchGeometry(
                    kind: .hardware,
                    baseSize: CGSize(width: notchWidth, height: m.safeAreaTop),
                    midX: m.frame.minX + left.width + notchWidth / 2,
                    screenTop: m.frame.maxY,
                    topInset: 0
                )
            }
        }
        return NotchGeometry(
            kind: .floating,
            baseSize: floatingPillSize,
            midX: m.frame.midX,
            screenTop: m.frame.maxY,
            topInset: floatingTopInset
        )
    }

    /// Automatic screen choice: the built-in notch screen if any, otherwise the main screen.
    public static func preferredIndex(in screens: [ScreenMetrics], mainIndex: Int?) -> Int? {
        screens.firstIndex(where: \.hasNotch) ?? mainIndex ?? (screens.isEmpty ? nil : 0)
    }
}

