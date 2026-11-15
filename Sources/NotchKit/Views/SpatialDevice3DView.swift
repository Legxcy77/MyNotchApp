import AppKit
import SceneKit
import SwiftUI

public enum SpatialDeviceKind: Equatable, Sendable {
    case airPods
    case magSafe(percent: Int, watts: Int?)
}

public struct SpatialDevice3DView: NSViewRepresentable {
    public let kind: SpatialDeviceKind

    public init(kind: SpatialDeviceKind) {
        self.kind = kind
    }

    public func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.scene = buildScene(for: kind)
        return view
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = buildScene(for: kind)
    }

    private func buildScene(for kind: SpatialDeviceKind) -> SCNScene {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.25, 3.6)
        scene.rootNode.addChildNode(cameraNode)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 1200
        keyLight.position = SCNVector3(2.5, 3.0, 4.0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 350
        scene.rootNode.addChildNode(fillLight)

        let rootModel = SCNNode()
        switch kind {
        case .airPods:
            let caseGeom = SCNBox(width: 1.35, height: 1.05, length: 0.55, chamferRadius: 0.22)
            let caseMat = SCNMaterial()
            caseMat.diffuse.contents = NSColor(white: 0.94, alpha: 1.0)
            caseMat.roughness.contents = 0.22
            caseMat.metalness.contents = 0.08
            caseGeom.materials = [caseMat]
            let caseNode = SCNNode(geometry: caseGeom)

            let ledGeom = SCNSphere(radius: 0.045)
            let ledMat = SCNMaterial()
            ledMat.diffuse.contents = NSColor.systemGreen
            ledMat.emission.contents = NSColor.systemGreen
            ledGeom.materials = [ledMat]
            let ledNode = SCNNode(geometry: ledGeom)
            ledNode.position = SCNVector3(0, 0.05, 0.28)

            let ringGeom = SCNTorus(ringRadius: 0.92, pipeRadius: 0.025)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = NSColor.systemCyan
            ringMat.emission.contents = NSColor.systemCyan.withAlphaComponent(0.55)
            ringGeom.materials = [ringMat]
            let ringNode = SCNNode(geometry: ringGeom)
            ringNode.eulerAngles = SCNVector3(Float.pi / 2.6, 0, 0)

            rootModel.addChildNode(caseNode)
            rootModel.addChildNode(ledNode)
            rootModel.addChildNode(ringNode)

        case .magSafe:
            let torus = SCNTorus(ringRadius: 0.78, pipeRadius: 0.14)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = NSColor.systemGreen
            ringMat.emission.contents = NSColor.systemGreen.withAlphaComponent(0.6)
            ringMat.roughness.contents = 0.18
            torus.materials = [ringMat]
            let torusNode = SCNNode(geometry: torus)
            torusNode.eulerAngles = SCNVector3(Float.pi / 2.2, 0, 0)

            let core = SCNCylinder(radius: 0.42, height: 0.14)
            let coreMat = SCNMaterial()
            coreMat.diffuse.contents = NSColor(white: 0.85, alpha: 1.0)
            coreMat.metalness.contents = 0.8
            coreMat.roughness.contents = 0.25
            core.materials = [coreMat]
            let coreNode = SCNNode(geometry: core)
            coreNode.eulerAngles = SCNVector3(Float.pi / 2.2, 0, 0)

            rootModel.addChildNode(torusNode)
            rootModel.addChildNode(coreNode)
        }

        let spin = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4.5)
        )
        rootModel.runAction(spin)
        scene.rootNode.addChildNode(rootModel)
        return scene
    }
}

