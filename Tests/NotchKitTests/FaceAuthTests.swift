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

    @Test func profileStoreSavesLoadsAndDeletesWith0600() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mynotch-face-test-\(UUID().uuidString)", isDirectory: true)
        let fileURL = tempDir.appendingPathComponent("face_profile.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = FaceProfile(embeddings: [[0.1, 0.2, 0.3]])
        #expect(FaceProfileStore.save(profile, to: fileURL) == true)
        #expect(FaceProfileStore.load(from: fileURL)?.embeddings == [[0.1, 0.2, 0.3]])

        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue
        #expect(perms == 0o600)

        #expect(FaceProfileStore.delete(at: fileURL) == true)
        #expect(FaceProfileStore.load(from: fileURL) == nil)
    }

    @Test func faceAlignerComputesRollAngleAnd112CropForTiltedEyes() {
        let imageSize = CGSize(width: 1280, height: 720)
        let faceBox = CGRect(x: 0.35, y: 0.25, width: 0.30, height: 0.45)

        // +15 degrees tilt in image coordinates
        let angleRad = 15.0 * .pi / 180.0
        let eyeCenter = CGPoint(x: 640, y: 400)
        let halfDist: CGFloat = 50
        let leftEye = CGPoint(
            x: eyeCenter.x - cos(angleRad) * halfDist,
            y: eyeCenter.y - sin(angleRad) * halfDist
        )
        let rightEye = CGPoint(
            x: eyeCenter.x + cos(angleRad) * halfDist,
            y: eyeCenter.y + sin(angleRad) * halfDist
        )

        let result = FaceAligner.computeAlignedCropRectAndAngle(
            leftEye: leftEye,
            rightEye: rightEye,
            faceBoundingBox: faceBox,
            imageSize: imageSize
        )

        #expect(abs(result.rollAngleRadians - angleRad) < 0.001)
        #expect(result.cropRect.width > 0)
        #expect(result.cropRect.height > 0)
        #expect(abs(result.targetSize.width - 112) < 0.01)
        #expect(abs(result.targetSize.height - 112) < 0.01)

        // Also test -15 degrees tilt
        let negAngle = -15.0 * .pi / 180.0
        let negLeft = CGPoint(
            x: eyeCenter.x - cos(negAngle) * halfDist,
            y: eyeCenter.y - sin(negAngle) * halfDist
        )
        let negRight = CGPoint(
            x: eyeCenter.x + cos(negAngle) * halfDist,
            y: eyeCenter.y + sin(negAngle) * halfDist
        )
        let negResult = FaceAligner.computeAlignedCropRectAndAngle(
            leftEye: negLeft,
            rightEye: negRight,
            faceBoundingBox: faceBox,
            imageSize: imageSize
        )
        #expect(abs(negResult.rollAngleRadians - negAngle) < 0.001)
    }
}
