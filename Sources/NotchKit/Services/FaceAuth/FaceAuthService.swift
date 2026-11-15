@preconcurrency import AVFoundation
import CoreImage
import Foundation
import os
import Vision

@MainActor
@Observable
public final class FaceAuthService {
    public enum PermissionStatus: Equatable, Sendable {
        case notDetermined
        case authorized
        case denied
    }

    public enum Mode: Equatable, Sendable {
        case idle
        case enrolling
        case verifying
        case enrolled
        case verified
        case failed(String)
    }

    public private(set) var permissionStatus: PermissionStatus
    public private(set) var mode: Mode = .idle
    public private(set) var enrollmentState = FaceEnrollmentState()
    public private(set) var hasEnrolledFace: Bool
    public private(set) var verifyMessage: String = "มองที่กล้องเพื่อปลดล็อก"

    public let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.pawalit.MyNotchApp.faceauth.session")
    private let processor = FaceFrameProcessor()
    private var isConfigured = false
    private var onVerifiedCallback: (@MainActor () -> Void)?

    public init() {
        self.permissionStatus = Self.currentPermissionStatus()
        self.hasEnrolledFace = FaceProfileStore.hasEnrolledFace
        self.processor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleProcessorEvent(event)
            }
        }
    }

    public func refreshPermissionStatus() {
        permissionStatus = Self.currentPermissionStatus()
        hasEnrolledFace = FaceProfileStore.hasEnrolledFace
    }

    public func requestPermissionAndStartEnrollment() {
        switch Self.currentPermissionStatus() {
        case .authorized:
            permissionStatus = .authorized
            startEnrollment()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.permissionStatus = granted ? .authorized : .denied
                    if granted {
                        self.startEnrollment()
                    }
                }
            }
        case .denied:
            permissionStatus = .denied
        }
    }

    public func startEnrollment() {
        enrollmentState = FaceEnrollmentState()
        mode = .enrolling
        processor.configureForEnrollment()
        startCameraSession()
    }

    public func startVerification(onVerified: @escaping @MainActor () -> Void) {
        guard let profile = FaceProfileStore.load(), !profile.embeddings.isEmpty else {
            mode = .failed("ยังไม่ได้ลงทะเบียนใบหน้า")
            return
        }
        guard Self.currentPermissionStatus() == .authorized else {
            permissionStatus = Self.currentPermissionStatus()
            mode = .failed("ยังไม่ได้อนุญาตใช้งานกล้อง")
            return
        }
        onVerifiedCallback = onVerified
        verifyMessage = "มองที่กล้องและกระพริบตาเบาๆ"
        mode = .verifying
        processor.configureForVerification(gallery: profile.embeddings)
        startCameraSession()
    }

    public func stop() {
        processor.reset()
        onVerifiedCallback = nil
        if mode == .enrolling || mode == .verifying {
            mode = .idle
        }
        let session = self.session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    public func clearEnrolledFace() {
        FaceProfileStore.delete()
        hasEnrolledFace = false
        if mode == .enrolled {
            mode = .idle
        }
    }

    private func startCameraSession() {
        let session = self.session
        let processor = self.processor
        let needsConfig = !isConfigured
        isConfigured = true

        sessionQueue.async {
            if needsConfig {
                session.beginConfiguration()
                session.sessionPreset = .medium

                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.alwaysDiscardsLateVideoFrames = true
                let visionQueue = DispatchQueue(label: "com.pawalit.MyNotchApp.faceauth.vision")
                output.setSampleBufferDelegate(processor, queue: visionQueue)
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                session.commitConfiguration()
            }

            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func handleProcessorEvent(_ event: FaceProcessorEvent) {
        switch event {
        case .enrollmentSample(let sample, let embedding):
            guard mode == .enrolling else { return }
            enrollmentState.ingest(sample)
            if let embedding {
                processor.appendEnrollmentEmbedding(embedding)
            }
            if enrollmentState.isComplete {
                let embeddings = processor.takeEnrollmentEmbeddings()
                if !embeddings.isEmpty, FaceProfileStore.save(FaceProfile(embeddings: embeddings)) {
                    hasEnrolledFace = true
                    mode = .enrolled
                } else {
                    mode = .failed("ไม่สามารถบันทึกข้อมูลใบหน้าได้")
                }
                let session = self.session
                sessionQueue.async {
                    if session.isRunning {
                        session.stopRunning()
                    }
                }
            }

        case .verificationStatus(let message):
            guard mode == .verifying else { return }
            verifyMessage = message

        case .verified:
            guard mode == .verifying else { return }
            mode = .verified
            let cb = onVerifiedCallback
            onVerifiedCallback = nil
            let session = self.session
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
            }
            cb?()
        }
    }

    private static func currentPermissionStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}

private enum FaceProcessorEvent: Sendable {
    case enrollmentSample(FacePoseSample?, [Float]?)
    case verificationStatus(String)
    case verified
}

// All mutable state is protected by OSAllocatedUnfairLock and accessed from the Vision capture queue.
private final class FaceFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private enum TaskMode {
        case idle
        case enroll
        case verify
    }

    private struct State {
        var mode: TaskMode = .idle
        var lastProcessedAt: TimeInterval = 0
        var lastEmbeddingAt: TimeInterval = 0
        var collectedEmbeddings: [[Float]] = []
        var gallery: [[Float]] = []
        var blinkDetector = BlinkDetector()
        var bestSimilarity: Float = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    var onEvent: (@Sendable (FaceProcessorEvent) -> Void)?

    func configureForEnrollment() {
        state.withLock { s in
            s.mode = .enroll
            s.collectedEmbeddings = []
            s.lastEmbeddingAt = 0
            s.blinkDetector.reset()
        }
    }

    func configureForVerification(gallery: [[Float]]) {
        state.withLock { s in
            s.mode = .verify
            s.gallery = gallery
            s.blinkDetector.reset()
            s.bestSimilarity = 0
        }
    }

    func reset() {
        state.withLock { s in
            s.mode = .idle
            s.collectedEmbeddings = []
            s.gallery = []
            s.blinkDetector.reset()
        }
    }

    func appendEnrollmentEmbedding(_ embedding: [Float]) {
        state.withLock { s in
            if s.collectedEmbeddings.count < 8 {
                s.collectedEmbeddings.append(embedding)
            }
        }
    }

    func takeEnrollmentEmbeddings() -> [[Float]] {
        state.withLock { s in
            let copy = s.collectedEmbeddings
            s.collectedEmbeddings = []
            s.mode = .idle
            return copy
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        let snapshot = state.withLock { s -> (TaskMode, [[Float]], Bool)? in
            guard s.mode != .idle else { return nil }
            guard now - s.lastProcessedAt >= 0.08 else { return nil } // ~12 fps cap
            s.lastProcessedAt = now
            let shouldCaptureEmbedding = (now - s.lastEmbeddingAt >= 0.45) && s.collectedEmbeddings.count < 8
            return (s.mode, s.gallery, shouldCaptureEmbedding)
        }
        guard let (mode, gallery, shouldCaptureEmbedding) = snapshot else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        try? handler.perform([landmarksRequest])

        guard let face = landmarksRequest.results?.first else {
            if mode == .enroll {
                onEvent?(.enrollmentSample(nil, nil))
            } else {
                onEvent?(.verificationStatus("ไม่พบใบหน้า กรุณามองที่กล้อง"))
            }
            return
        }

        let sample = Self.poseSample(from: face)

        switch mode {
        case .idle:
            break
        case .enroll:
            var embedding: [Float]?
            if shouldCaptureEmbedding, sample.faceArea >= 0.05 {
                embedding = extractFeaturePrint(from: pixelBuffer, faceBoundingBox: face.boundingBox)
                if embedding != nil {
                    state.withLock { $0.lastEmbeddingAt = now }
                }
            }
            onEvent?(.enrollmentSample(sample, embedding))

        case .verify:
            let livenessPassed = state.withLock { s -> Bool in
                s.blinkDetector.ingest(eyeAspectRatio: sample.eyeAspectRatio)
                return s.blinkDetector.didBlink
            }

            guard let probe = extractFeaturePrint(from: pixelBuffer, faceBoundingBox: face.boundingBox) else {
                return
            }
            let sim = FaceEmbeddingMath.bestSimilarity(probe: probe, gallery: gallery)
            let isMatch = sim >= 0.76

            if isMatch && livenessPassed {
                state.withLock { $0.mode = .idle }
                onEvent?(.verified)
            } else if isMatch {
                onEvent?(.verificationStatus("กระพริบตา 1 ครั้งเพื่อยืนยันตัวตน"))
            } else {
                onEvent?(.verificationStatus("กำลังสแกนใบหน้า..."))
            }
        }
    }

    private func extractFeaturePrint(from pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> [Float]? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.upMirrored)
        let extent = image.extent
        let padX = faceBoundingBox.width * 0.10
        let padY = faceBoundingBox.height * 0.10
        let padded = CGRect(
            x: max(0, faceBoundingBox.minX - padX),
            y: max(0, faceBoundingBox.minY - padY),
            width: min(1, faceBoundingBox.width + padX * 2),
            height: min(1, faceBoundingBox.height + padY * 2)
        )
        let cropRect = CGRect(
            x: padded.minX * extent.width,
            y: padded.minY * extent.height,
            width: padded.width * extent.width,
            height: padded.height * extent.height
        ).intersection(extent)
        guard !cropRect.isEmpty else { return nil }

        let cropped = image.cropped(to: cropRect)
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(ciImage: cropped, options: [:])
        try? handler.perform([request])
        guard let obs = request.results?.first, obs.elementType == .float else { return nil }

        let count = obs.elementCount
        var floats = [Float](repeating: 0, count: count)
        obs.data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Float.self)
            for i in 0..<min(count, src.count) {
                floats[i] = src[i]
            }
        }
        return floats
    }

    private static func poseSample(from face: VNFaceObservation) -> FacePoseSample {
        let yaw = face.yaw?.doubleValue ?? 0
        let pitch: Double
        if let directPitch = face.pitch?.doubleValue {
            pitch = directPitch
        } else if let nose = face.landmarks?.noseCrest?.normalizedPoints,
                  let leftEye = face.landmarks?.leftEye?.normalizedPoints,
                  let rightEye = face.landmarks?.rightEye?.normalizedPoints,
                  let noseTip = nose.last,
                  !leftEye.isEmpty, !rightEye.isEmpty {
            let leftSum = leftEye.reduce(0.0) { $0 + Double($1.y) }
            let rightSum = rightEye.reduce(0.0) { $0 + Double($1.y) }
            let leftY = leftSum / Double(leftEye.count)
            let rightY = rightSum / Double(rightEye.count)
            let eyeY = (leftY + rightY) / 2.0
            // Neutral noseTip is ~0.22 below eyeY in normalized face coordinates
            pitch = (eyeY - Double(noseTip.y) - 0.22) * -2.2
        } else {
            pitch = 0
        }

        let leftEAR = eyeAspectRatio(for: face.landmarks?.leftEye)
        let rightEAR = eyeAspectRatio(for: face.landmarks?.rightEye)
        let ear: Double
        if leftEAR > 0 && rightEAR > 0 {
            ear = (leftEAR + rightEAR) / 2.0
        } else {
            ear = max(leftEAR, rightEAR)
        }

        let area = Double(face.boundingBox.width * face.boundingBox.height)
        return FacePoseSample(yaw: yaw, pitch: pitch, eyeAspectRatio: ear, faceArea: area)
    }

    private static func eyeAspectRatio(for region: VNFaceLandmarkRegion2D?) -> Double {
        guard let points = region?.normalizedPoints, points.count >= 4 else { return 0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return 0 }
        let width = Double(maxX - minX)
        let height = Double(maxY - minY)
        guard width > 0.001 else { return 0 }
        return height / width
    }
}
