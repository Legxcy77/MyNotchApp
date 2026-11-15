import Foundation

public struct FacePoseSample: Equatable, Sendable {
    public let yaw: Double
    public let pitch: Double
    public let eyeAspectRatio: Double
    public let faceArea: Double

    public init(yaw: Double, pitch: Double, eyeAspectRatio: Double, faceArea: Double) {
        self.yaw = yaw
        self.pitch = pitch
        self.eyeAspectRatio = eyeAspectRatio
        self.faceArea = faceArea
    }
}

public enum FaceGuidance: Equatable, Sendable {
    case noFace
    case moveCloser
    case lookStraight
    case turnLeft
    case turnRight
    case lookUp
    case lookDown
    case blinkToConfirm
    case completed

    public var message: String {
        switch self {
        case .noFace: return "วางใบหน้าให้อยู่ในวงกลม"
        case .moveCloser: return "ขยับหน้าเข้ามาใกล้กล้องอีกนิด"
        case .lookStraight: return "มองตรงที่กล้อง"
        case .turnLeft: return "หันหน้าไปทางซ้ายช้าๆ"
        case .turnRight: return "หันหน้าไปทางขวาช้าๆ"
        case .lookUp: return "เงยหน้าขึ้นเล็กน้อย"
        case .lookDown: return "ก้มหน้าลงเล็กน้อย"
        case .blinkToConfirm: return "กระพริบตา 1 ครั้งเพื่อยืนยัน"
        case .completed: return "สแกนใบหน้าสำเร็จ"
        }
    }
}

public struct BlinkDetector: Equatable, Sendable {
    private var sawClosedEye = false
    public private(set) var didBlink = false

    public init() {}

    public mutating func ingest(eyeAspectRatio: Double) {
        guard !didBlink, eyeAspectRatio > 0 else { return }
        if eyeAspectRatio < 0.17 {
            sawClosedEye = true
        } else if sawClosedEye, eyeAspectRatio > 0.21 {
            didBlink = true
        }
    }

    public mutating func reset() {
        sawClosedEye = false
        didBlink = false
    }
}

public struct FaceEnrollmentState: Equatable, Sendable {
    public static let segmentCount = 16
    public private(set) var segments: [Bool]
    public private(set) var hasBaselineFront = false
    public private(set) var blinkConfirmed = false
    public private(set) var guidance: FaceGuidance = .lookStraight

    private var blinkDetector = BlinkDetector()

    public init() {
        self.segments = Array(repeating: false, count: Self.segmentCount)
    }

    public var completedCount: Int {
        segments.filter { $0 }.count
    }

    public var progress: Double {
        Double(completedCount) / Double(Self.segmentCount)
    }

    public var isComplete: Bool {
        completedCount == Self.segmentCount && blinkConfirmed
    }

    public mutating func ingest(_ sample: FacePoseSample?) {
        guard !isComplete else {
            guidance = .completed
            return
        }

        guard let sample else {
            guidance = .noFace
            return
        }

        guard sample.faceArea >= 0.05 else {
            guidance = .moveCloser
            return
        }

        // Track blink at any time once face is visible
        blinkDetector.ingest(eyeAspectRatio: sample.eyeAspectRatio)
        if blinkDetector.didBlink {
            blinkConfirmed = true
        }

        let magnitude = hypot(sample.yaw, sample.pitch)
        if magnitude < 0.14 {
            hasBaselineFront = true
        } else {
            // Map head direction angle to 16 ring segments (0 = top/up, clockwise)
            // Note: on mirrored front camera, yaw < 0 is turning left, yaw > 0 is turning right.
            let angle = atan2(sample.yaw, sample.pitch) // [-pi, pi], 0 = up, +pi/2 = right, -pi/2 = left, +/-pi = down
            let normalized = angle >= 0 ? angle : (angle + 2 * .pi)
            let exactIndex = (normalized / (2 * .pi)) * Double(Self.segmentCount)
            let centerIndex = Int(exactIndex.rounded()) % Self.segmentCount

            // Fill target segment and immediate neighbor within tolerance so sweeping feels smooth like Canopy
            let prev = (centerIndex - 1 + Self.segmentCount) % Self.segmentCount
            let next = (centerIndex + 1) % Self.segmentCount
            segments[centerIndex] = true
            if magnitude >= 0.18 {
                segments[prev] = true
                segments[next] = true
            }
        }

        updateGuidance()
    }

    private mutating func updateGuidance() {
        if isComplete {
            guidance = .completed
            return
        }
        if !hasBaselineFront {
            guidance = .lookStraight
            return
        }

        // Segment groups:
        // Top: 15, 0, 1 | Right: 2, 3, 4, 5, 6 | Bottom: 7, 8, 9 | Left: 10, 11, 12, 13, 14
        let leftDone = (10...14).allSatisfy { segments[$0] }
        let rightDone = (2...6).allSatisfy { segments[$0] }
        let topDone = [15, 0, 1].allSatisfy { segments[$0] }
        let bottomDone = (7...9).allSatisfy { segments[$0] }

        if !leftDone {
            guidance = .turnLeft
        } else if !rightDone {
            guidance = .turnRight
        } else if !topDone {
            guidance = .lookUp
        } else if !bottomDone {
            guidance = .lookDown
        } else if !blinkConfirmed {
            guidance = .blinkToConfirm
        } else {
            guidance = .completed
        }
    }
}

public enum FaceEmbeddingMath {
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    public static func bestSimilarity(probe: [Float], gallery: [[Float]]) -> Float {
        gallery.map { cosineSimilarity(probe, $0) }.max() ?? 0
    }
}

