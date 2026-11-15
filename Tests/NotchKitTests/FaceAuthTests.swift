import Foundation
import Testing
@testable import NotchKit

@Suite("FaceAuthTests")
struct FaceAuthTests {
    @Test func enrollmentGuidesThroughAnglesAndBlinkToCompletion() {
        var state = FaceEnrollmentState()
        #expect(state.completedCount == 0)
        #expect(state.isComplete == false)
        #expect(state.guidance == .lookStraight)

        // Looking straight establishes baseline and advances guidance to turning left
        state.ingest(FacePoseSample(yaw: 0.0, pitch: 0.0, eyeAspectRatio: 0.28, faceArea: 0.15))
        #expect(state.hasBaselineFront == true)
        #expect(state.guidance == .turnLeft)

        // Sweeping head around left, right, up, down fills all 16 segments
        let sweepAngles: [(Double, Double)] = [
            (-0.35, 0.0), (-0.28, 0.18), (0.0, 0.25), (0.28, 0.18),
            (0.35, 0.0), (0.28, -0.18), (0.0, -0.25), (-0.28, -0.18),
            (-0.40, 0.08), (-0.40, -0.08), (0.40, 0.08), (0.40, -0.08),
            (-0.18, 0.22), (0.18, 0.22), (-0.18, -0.22), (0.18, -0.22),
        ]
        for (yaw, pitch) in sweepAngles {
            state.ingest(FacePoseSample(yaw: yaw, pitch: pitch, eyeAspectRatio: 0.28, faceArea: 0.15))
        }

        #expect(state.completedCount == 16)
        #expect(state.isComplete == false)
        #expect(state.guidance == .blinkToConfirm)

        // Blink: eyes close then open
        state.ingest(FacePoseSample(yaw: 0.0, pitch: 0.0, eyeAspectRatio: 0.12, faceArea: 0.15))
        state.ingest(FacePoseSample(yaw: 0.0, pitch: 0.0, eyeAspectRatio: 0.27, faceArea: 0.15))

        #expect(state.blinkConfirmed == true)
        #expect(state.isComplete == true)
        #expect(state.guidance == .completed)
    }

    @Test func rejectsSmallOrMissingFace() {
        var state = FaceEnrollmentState()
        state.ingest(FacePoseSample(yaw: 0.0, pitch: 0.0, eyeAspectRatio: 0.28, faceArea: 0.02))
        #expect(state.completedCount == 0)
        #expect(state.guidance == .moveCloser)
    }

    @Test func cosineSimilarityDistinguishesSameVsDifferentEmbeddings() {
        let a: [Float] = [0.6, 0.8, 0.0, 0.0]
        let aClose: [Float] = [0.58, 0.81, 0.05, 0.0]
        let bDiff: [Float] = [-0.5, 0.1, 0.85, 0.1]

        let simSame = FaceEmbeddingMath.cosineSimilarity(a, aClose)
        let simDiff = FaceEmbeddingMath.cosineSimilarity(a, bDiff)

        #expect(simSame > 0.98)
        #expect(simDiff < 0.2)
        #expect(FaceEmbeddingMath.bestSimilarity(probe: aClose, gallery: [bDiff, a]) == simSame)
    }
}
