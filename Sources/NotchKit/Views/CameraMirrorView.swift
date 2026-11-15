import AppKit
@preconcurrency import AVFoundation
import SwiftUI

struct CameraMirrorView: View {
    @State private var authStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        ZStack {
            switch authStatus {
            case .authorized:
                CameraPreviewRepresentable()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .notDetermined:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        authStatus = granted ? .authorized : .denied
                    }
            default:
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Camera access needed in System Settings → Privacy → Camera")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.start()
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.stop()
    }
}

@MainActor
private final class CameraPreviewNSView: NSView {
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.camera")
    private var isConfigured = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    func start() {
        let session = self.session
        let alreadyConfigured = self.isConfigured
        self.isConfigured = true

        queue.async {
            if !alreadyConfigured {
                session.beginConfiguration()
                session.sessionPreset = .medium
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        let session = self.session
        queue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}
