import CoreGraphics
import Testing
@testable import NotchKit

// MBP 14" (3024x1964 @2x → 1512x982 pt). Notch ≈ 185pt wide, 32pt tall.
private let mbp14 = ScreenMetrics(
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    safeAreaTop: 32,
    auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 663.5, height: 32),
    auxiliaryTopRight: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
)

@Suite struct ScreenGeometryTests {
    @Test func hardwareNotchIsMeasuredFromAuxiliaryAreas() {
        let g = ScreenGeometry.resolve(mbp14)
        #expect(g.kind == .hardware)
        #expect(g.baseSize == CGSize(width: 185, height: 32))
        #expect(g.midX == 756)
        #expect(g.topInset == 0)
        #expect(g.islandRect(size: g.baseSize) == CGRect(x: 663.5, y: 950, width: 185, height: 32))
    }

    @Test func externalDisplayFallsBackToFloatingPill() {
        let external = ScreenMetrics(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), safeAreaTop: 0)
        let g = ScreenGeometry.resolve(external)
        #expect(g.kind == .floating)
        #expect(g.midX == CGFloat(2792))
        #expect(g.cameraClearance == 0)
        #expect(g.islandRect(size: g.baseSize).maxY == 1440 - ScreenGeometry.floatingTopInset)
    }

    @Test func degenerateAuxiliaryAreasFallBack() {
        var m = mbp14
        m.auxiliaryTopLeft = CGRect(x: 0, y: 0, width: 800, height: 32)
        m.auxiliaryTopRight = CGRect(x: 0, y: 0, width: 800, height: 32)
        #expect(ScreenGeometry.resolve(m).kind == .floating)
        m.auxiliaryTopRight = nil
        #expect(ScreenGeometry.resolve(m).kind == .floating)
    }

    @Test func prefersNotchScreenOverMain() {
        let ext = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), safeAreaTop: 0)
        #expect(ScreenGeometry.preferredIndex(in: [ext, mbp14], mainIndex: 0) == 1)
        #expect(ScreenGeometry.preferredIndex(in: [ext, ext], mainIndex: 1) == 1)
        #expect(ScreenGeometry.preferredIndex(in: [], mainIndex: nil) == nil)
    }

    @Test func collapsedHitRectIsForgivingAndReachesTopEdge() {
        let g = ScreenGeometry.resolve(mbp14)
        let r = IslandLayout.hitRect(for: .collapsed, geometry: g)
        #expect(r.contains(CGPoint(x: 756, y: 981)))
        #expect(r.contains(CGPoint(x: 663.5 - 10, y: 960)))
        #expect(!r.contains(CGPoint(x: 400, y: 960)))
    }

    @Test func expandedContentNeverUsesCameraArea() {
        let g = ScreenGeometry.resolve(mbp14)
        let s = IslandLayout.size(for: .expanded, geometry: g)
        #expect(s.height == 32 + IslandLayout.expandedSize.height)
        #expect(s.width <= IslandLayout.panelSize.width)
    }

    @Test func notchIslandShapeProducesValidPathBounds() {
        let shape = NotchIslandShape(topEarRadius: 8, topCornerRadius: 0, bottomCornerRadius: 28)
        let rect = CGRect(x: 0, y: 0, width: 420, height: 220)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
        #expect(path.boundingRect.width >= rect.width)
        #expect(abs(path.boundingRect.height - rect.height) < 1.0)
    }

    @Test func swipeGestureRecognizerDetectsDirectionsAndIgnoresMomentum() {
        var recognizer = SwipeGestureRecognizer(threshold: 28)

        #expect(recognizer.ingest(deltaX: 0, deltaY: -10, phase: .began) == nil)
        #expect(recognizer.ingest(deltaX: 0, deltaY: -22, phase: .changed) == .down)
        // Must not refire within the same gesture or during momentum
        #expect(recognizer.ingest(deltaX: 0, deltaY: -40, phase: .changed) == nil)
        #expect(recognizer.ingest(deltaX: 0, deltaY: -40, phase: .momentum) == nil)
        #expect(recognizer.ingest(deltaX: 0, deltaY: 0, phase: .ended) == nil)

        // New gesture: swipe up
        #expect(recognizer.ingest(deltaX: 0, deltaY: 35, phase: .began) == .up)
        #expect(recognizer.ingest(deltaX: 0, deltaY: 0, phase: .ended) == nil)

        // New gesture: swipe left / right
        #expect(recognizer.ingest(deltaX: -32, deltaY: 2, phase: .began) == .left)
        #expect(recognizer.ingest(deltaX: 0, deltaY: 0, phase: .ended) == nil)
        #expect(recognizer.ingest(deltaX: 32, deltaY: -2, phase: .began) == .right)
    }
}
