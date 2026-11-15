import AppKit
import AVFoundation
import SwiftUI

public struct FaceEnrollmentView: View {
    @Bindable var service: FaceAuthService
    let onClose: () -> Void

    public init(service: FaceAuthService, onClose: @escaping () -> Void) {
        self.service = service
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 18) {
            header

            switch service.mode {
            case .enrolling:
                canopyScannerView
            case .enrolled:
                enrolledSuccessView
            case .failed(let message):
                failedView(message)
            case .idle, .verifying, .verified:
                permissionAndSetupView
            }
        }
        .padding(24)
        .frame(width: 360, height: 430)
        .background(Color.black)
        .onAppear {
            service.refreshPermissionStatus()
        }
        .onDisappear {
            service.stop()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "faceid")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Face Unlock Setup")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: {
                service.stop()
                onClose()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
    }

    private var permissionAndSetupView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 96, height: 96)
                Image(systemName: service.hasEnrolledFace ? "checkmark.shield.fill" : "faceid")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(service.hasEnrolledFace ? Color.green : Color.white.opacity(0.85))
            }

            VStack(spacing: 6) {
                Text(service.hasEnrolledFace ? "ลงทะเบียนใบหน้าไว้แล้ว" : "ตั้งค่าการสแกนใบหน้า")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("ระบบขออนุญาตใช้กล้องเพื่อสแกนใบหน้าแบบ Canopy ประมวลผลบนเครื่อง 100% และเก็บเฉพาะค่าจำลองใบหน้าใน Keychain")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if service.permissionStatus == .denied {
                Text("กล้องถูกปิดสิทธิ์ไว้ กรุณาเปิดสิทธิ์ใน System Settings > Privacy & Security > Camera")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)

                Button("เปิด Camera Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(action: {
                    service.requestPermissionAndStartEnrollment()
                }) {
                    Text(service.hasEnrolledFace ? "สแกนใบหน้าใหม่" : "อนุญาตใช้กล้องและเริ่มสแกน")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if service.hasEnrolledFace {
                    Button("ลบข้อมูลใบหน้า") {
                        service.clearEnrolledFace()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.85))
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    private var canopyScannerView: some View {
        VStack(spacing: 16) {
            ZStack {
                CameraPreviewLayerView(session: service.session)
                    .frame(width: 196, height: 196)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                CanopyRingView(segments: service.enrollmentState.segments)
                    .frame(width: 232, height: 232)
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                Text(service.enrollmentState.guidance.message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: service.enrollmentState.guidance)

                HStack(spacing: 14) {
                    let pct = Int((service.enrollmentState.progress * 100).rounded())
                    Label("\(pct)%", systemImage: "circle.dashed")
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))

                    Label(
                        service.enrollmentState.blinkConfirmed ? "กระพริบตาแล้ว" : "รอกระพริบตา",
                        systemImage: service.enrollmentState.blinkConfirmed ? "eye.fill" : "eye"
                    )
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(service.enrollmentState.blinkConfirmed ? Color.green : .white.opacity(0.5))
                }
            }

            Button("ยกเลิก") {
                service.stop()
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.5))
            .buttonStyle(.plain)
        }
    }

    private var enrolledSuccessView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("บันทึกใบหน้าเรียบร้อย")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("ข้อมูลใบหน้าถูกบันทึกใน Keychain อย่างปลอดภัยแล้ว")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: {
                onClose()
            }) {
                Text("เสร็จสิ้น")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button("ลองใหม่") {
                service.requestPermissionAndStartEnrollment()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

private struct CanopyRingView: View {
    let segments: [Bool]

    var body: some View {
        ZStack {
            ForEach(0..<segments.count, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(segments.count))
                let active = segments[index]
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(active ? Color.green : Color.white.opacity(0.18))
                    .frame(width: 4, height: active ? 16 : 11)
                    .offset(y: -108)
                    .rotationEffect(.degrees(angle))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
            }
        }
    }
}

private struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
    }

    final class PreviewNSView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = previewLayer
            // Mirror horizontally so moving left/right feels natural like a mirror
            previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

