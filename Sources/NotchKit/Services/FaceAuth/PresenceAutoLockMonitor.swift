@preconcurrency import AVFoundation
import Foundation
import Vision

public enum WalkAwayAction: Equatable, Sendable {
    case none
    case countdown(remainingSeconds: Int)
    case triggerLock
    case cancelled
}

public struct WalkAwayCountdownTracker: Sendable {
    public var absenceThreshold: TimeInterval
    public var countdownDuration: TimeInterval

    private var lastFaceSeenAt: Date?
    private var countdownStartedAt: Date?
    private var suppressedUntil: Date?

    public init(absenceThreshold: TimeInterval = 30, countdownDuration: TimeInterval = 3) {
        self.absenceThreshold = max(5, absenceThreshold)
        self.countdownDuration = max(1, countdownDuration)
    }

    public mutating func cancel(at date: Date = Date()) {
        countdownStartedAt = nil
        lastFaceSeenAt = date
        suppressedUntil = date.addingTimeInterval(absenceThreshold)
    }

    public mutating func recordSample(faceDetected: Bool, at date: Date = Date()) -> WalkAwayAction {
        if faceDetected {
            let wasCounting = countdownStartedAt != nil
            lastFaceSeenAt = date
            countdownStartedAt = nil
            suppressedUntil = nil
            return wasCounting ? .cancelled : .none
        }

        if let suppressedUntil, date < suppressedUntil {
            return .none
        }

        if lastFaceSeenAt == nil {
            lastFaceSeenAt = date
            return .none
        }

        let absentFor = date.timeIntervalSince(lastFaceSeenAt!)
        guard absentFor >= absenceThreshold else {
            return .none
        }

        if countdownStartedAt == nil {
            countdownStartedAt = date
        }

        let elapsedCountdown = date.timeIntervalSince(countdownStartedAt!)
        let remaining = Int(ceil(countdownDuration - elapsedCountdown))
        if remaining <= 0 {
            countdownStartedAt = nil
            lastFaceSeenAt = nil
            return .triggerLock
        }
        return .countdown(remainingSeconds: remaining)
    }
}

@MainActor
public final class PresenceAutoLockMonitor {
    private var tracker = WalkAwayCountdownTracker()
    private var task: Task<Void, Never>?
    private var isEnabled = false
    private let onCountdown: @MainActor (Int) -> Void
    private let onCancelCountdown: @MainActor () -> Void
    private let onTriggerLock: @MainActor () -> Void

    public init(
        onCountdown: @escaping @MainActor (Int) -> Void,
        onCancelCountdown: @escaping @MainActor () -> Void,
        onTriggerLock: @escaping @MainActor () -> Void
    ) {
        self.onCountdown = onCountdown
        self.onCancelCountdown = onCancelCountdown
        self.onTriggerLock = onTriggerLock
    }

    public func configure(enabled: Bool, thresholdSeconds: Int) {
        tracker.absenceThreshold = TimeInterval(max(10, thresholdSeconds))
        if enabled == isEnabled { return }
        isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    public func cancelCurrentCountdown() {
        tracker.cancel()
        onCancelCountdown()
    }

    public func start() {
        stop()
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { break }
                let detected = await Self.captureSingleFacePresence()
                self.handleSample(detected)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func handleSample(_ detected: Bool) {
        switch tracker.recordSample(faceDetected: detected) {
        case .none:
            break
        case .countdown(let remaining):
            onCountdown(remaining)
        case .cancelled:
            onCancelCountdown()
        case .triggerLock:
            onTriggerLock()
        }
    }

    private static func captureSingleFacePresence() async -> Bool {
        await Task.detached(priority: .utility) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return true
            }
            let session = AVCaptureSession()
            session.sessionPreset = .low
            let output = AVCaptureVideoDataOutput()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                return true
            }
            session.addInput(input)
            session.addOutput(output)

            final class FrameLatch: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private var continuation: CheckedContinuation<Bool, Never>?

                init(continuation: CheckedContinuation<Bool, Never>) {
                    self.continuation = continuation
                }

                func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                    let request = VNDetectFaceRectanglesRequest()
                    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                    try? handler.perform([request])
                    let hasFace = !(request.results?.isEmpty ?? true)
                    finish(with: hasFace)
                }

                func finish(with value: Bool) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation?.resume(returning: value)
                    continuation = nil
                }
            }

            return await withCheckedContinuation { cont in
                let latch = FrameLatch(continuation: cont)
                let queue = DispatchQueue(label: "mynotch.presence.sample")
                output.setSampleBufferDelegate(latch, queue: queue)
                session.startRunning()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2) {
                    session.stopRunning()
                    latch.finish(with: true)
                }
            }
        }.value
    }
}

