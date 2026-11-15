import AppKit
import MetalKit
import SwiftUI

public struct AuroraPalette: Equatable, Sendable {
    public var primary: SIMD3<Float>
    public var secondary: SIMD3<Float>
    public var accent: SIMD3<Float>

    public init(primary: SIMD3<Float>, secondary: SIMD3<Float>, accent: SIMD3<Float>) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
    }

    public static let midnight = AuroraPalette(
        primary: SIMD3<Float>(0.18, 0.38, 0.88),
        secondary: SIMD3<Float>(0.48, 0.22, 0.85),
        accent: SIMD3<Float>(0.10, 0.72, 0.78)
    )

    public static func from(tint: Toast.Tint?) -> AuroraPalette {
        switch tint {
        case .success:
            return AuroraPalette(
                primary: SIMD3<Float>(0.12, 0.80, 0.44),
                secondary: SIMD3<Float>(0.08, 0.56, 0.52),
                accent: SIMD3<Float>(0.34, 0.92, 0.60)
            )
        case .failure:
            return AuroraPalette(
                primary: SIMD3<Float>(0.92, 0.24, 0.24),
                secondary: SIMD3<Float>(0.72, 0.14, 0.34),
                accent: SIMD3<Float>(0.98, 0.44, 0.26)
            )
        case .waiting:
            return AuroraPalette(
                primary: SIMD3<Float>(0.95, 0.56, 0.16),
                secondary: SIMD3<Float>(0.78, 0.32, 0.18),
                accent: SIMD3<Float>(0.98, 0.76, 0.28)
            )
        case .info:
            return AuroraPalette(
                primary: SIMD3<Float>(0.22, 0.58, 0.98),
                secondary: SIMD3<Float>(0.46, 0.30, 0.92),
                accent: SIMD3<Float>(0.24, 0.84, 0.94)
            )
        case .neutral, .none:
            return .midnight
        }
    }

    public static func from(imageData: Data?) -> AuroraPalette {
        guard let imageData,
              let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .midnight
        }

        let size = 4
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .midnight
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        func sample(_ idx: Int) -> SIMD3<Float> {
            let offset = idx * 4
            let r = Float(bytes[offset]) / 255.0
            let g = Float(bytes[offset + 1]) / 255.0
            let b = Float(bytes[offset + 2]) / 255.0
            return SIMD3<Float>(max(0.08, r), max(0.08, g), max(0.12, b))
        }

        return AuroraPalette(
            primary: sample(5),
            secondary: sample(10),
            accent: sample(1)
        )
    }
}

public struct AuroraMetalView: NSViewRepresentable {
    public let palette: AuroraPalette
    public let intensity: Double

    public init(palette: AuroraPalette = .midnight, intensity: Double = 0.75) {
        self.palette = palette
        self.intensity = intensity
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(palette: palette, intensity: Float(intensity))
    }

    public func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        view.preferredFramesPerSecond = 30
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.delegate = context.coordinator
        context.coordinator.setup(device: view.device)
        return view
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.palette = palette
        context.coordinator.intensity = Float(intensity)
    }

    @MainActor
    public final class Coordinator: NSObject, MTKViewDelegate {
        private struct Uniforms {
            var time: Float
            var intensity: Float
            var padding: SIMD2<Float> = .zero
            var primary: SIMD4<Float>
            var secondary: SIMD4<Float>
            var accent: SIMD4<Float>
        }

        var palette: AuroraPalette
        var intensity: Float
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private let startTime = CACurrentMediaTime()

        private static let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float time;
            float intensity;
            float2 padding;
            float4 primary;
            float4 secondary;
            float4 accent;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        vertex VertexOut aurora_vertex(uint vid [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };
            float2 uvs[4] = {
                float2(0.0, 0.0),
                float2(1.0, 0.0),
                float2(0.0, 1.0),
                float2(1.0, 1.0)
            };
            VertexOut out;
            out.position = float4(positions[vid], 0.0, 1.0);
            out.uv = uvs[vid];
            return out;
        }

        fragment float4 aurora_fragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float2 uv = in.uv;
            float t = u.time * 0.45;
            float wave1 = sin(uv.x * 3.4 + t + cos(uv.y * 2.5 - t * 0.7)) * 0.5 + 0.5;
            float wave2 = cos(uv.x * 2.2 - t * 0.8 + sin(uv.y * 3.8 + t * 0.6)) * 0.5 + 0.5;
            float ribbon = smoothstep(0.15, 0.92, wave1 * 0.65 + wave2 * 0.45);
            float3 col = mix(u.primary.rgb, u.secondary.rgb, wave1);
            col = mix(col, u.accent.rgb, wave2 * 0.45);
            float vignette = 1.0 - smoothstep(0.25, 0.95, length(uv - float2(0.5, 0.5)));
            float alpha = clamp(ribbon * (0.35 + vignette * 0.65) * u.intensity, 0.0, 0.92);
            return float4(col * alpha, alpha);
        }
        """

        init(palette: AuroraPalette, intensity: Float) {
            self.palette = palette
            self.intensity = intensity
        }

        func setup(device: MTLDevice?) {
            guard let device else { return }
            commandQueue = device.makeCommandQueue()
            guard let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
                  let vfn = library.makeFunction(name: "aurora_vertex"),
                  let ffn = library.makeFunction(name: "aurora_fragment") else {
                return
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vfn
            desc.fragmentFunction = ffn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .one
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .one
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try? device.makeRenderPipelineState(descriptor: desc)
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            guard let pipelineState,
                  let commandQueue,
                  let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor,
                  let cmd = commandQueue.makeCommandBuffer(),
                  let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else {
                return
            }

            var uniforms = Uniforms(
                time: Float(CACurrentMediaTime() - startTime),
                intensity: intensity,
                primary: SIMD4<Float>(palette.primary, 1),
                secondary: SIMD4<Float>(palette.secondary, 1),
                accent: SIMD4<Float>(palette.accent, 1)
            )
            enc.setRenderPipelineState(pipelineState)
            enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
            cmd.present(drawable)
            cmd.commit()
        }
    }
}
