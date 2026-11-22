import SwiftUI
import ARKit
import RealityKit

struct ARPaintingView: View {
    let imageURL: URL?
    let dimensions: ArtworkDimensions

    @State private var message = "Point at a wall to begin"
    @State private var isPlaced = false

    var body: some View {
        if ARWorldTrackingConfiguration.isSupported {
            ZStack(alignment: .bottom) {
                ARContainer(imageURL: imageURL, dimensions: dimensions, message: $message, isPlaced: $isPlaced)
                    .ignoresSafeArea()
                Text(isPlaced ? "Tap again to reposition" : message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 32)
            }
        } else {
            ContentUnavailableView(
                "AR Not Available",
                systemImage: "arkit",
                description: Text("This device doesn't support world tracking AR.")
            )
            .background(Color.black)
        }
    }
}

private struct ARContainer: UIViewRepresentable {
    let imageURL: URL?
    let dimensions: ArtworkDimensions
    @Binding var message: String
    @Binding var isPlaced: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .verticalPlane
        coaching.activatesAutomatically = true
        arView.addSubview(coaching)

        arView.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        )
        context.coordinator.arView = arView
        context.coordinator.loadTexture()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        let parent: ARContainer
        weak var arView: ARView?
        var texture: TextureResource?
        var currentAnchor: AnchorEntity?

        init(_ parent: ARContainer) { self.parent = parent }

        func loadTexture() {
            guard let url = parent.imageURL else { return }
            Task {
                guard
                    let (data, _) = try? await URLSession.shared.data(from: url),
                    let cg = UIImage(data: data)?.cgImage,
                    let tex = try? await TextureResource.generate(from: cg, options: .init(semantic: .color))
                else { return }
                texture = tex
            }
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let pt = gesture.location(in: arView)
            guard let hit = arView.raycast(from: pt, allowing: .estimatedPlane, alignment: .vertical).first else {
                parent.message = "No wall detected here — try a different spot"
                return
            }
            placeArtwork(at: hit.worldTransform)
        }

        func placeArtwork(at transform: simd_float4x4) {
            guard let arView else { return }
            currentAnchor?.removeFromParent()

            let cm = parent.dimensions.sizeInCentimeters
            let w = Float(cm.width) / 100
            let h = Float(cm.height) / 100
            let border: Float = 0.012

            // Frame — slightly larger dark plane
            let frameEnt = makeTile(w: w + border * 2, h: h + border * 2, color: UIColor(white: 0.08, alpha: 1))

            // Canvas — artwork texture
            let canvasEnt = makeTile(w: w, h: h, color: .white)
            if let tex = texture {
                var mat = SimpleMaterial()
                mat.color = .init(tint: .white, texture: .init(tex))
                mat.roughness = 0.95
                mat.metallic = 0
                canvasEnt.model?.materials = [mat]
            }
            canvasEnt.position.z = 0.002 // slightly in front of frame

            let group = Entity()
            group.addChild(frameEnt)
            group.addChild(canvasEnt)

            // generatePlane(width:depth:) lies in XZ, normal +Y.
            // Rotate π/2 around X → plane stands upright in XY, normal +Z facing viewer.
            group.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

            let anchor = AnchorEntity(world: transform)
            anchor.addChild(group)
            arView.scene.addAnchor(anchor)
            currentAnchor = anchor
            parent.isPlaced = true
        }

        private func makeTile(w: Float, h: Float, color: UIColor) -> ModelEntity {
            var mat = SimpleMaterial()
            mat.color = .init(tint: color)
            return ModelEntity(mesh: .generatePlane(width: w, depth: h), materials: [mat])
        }
    }
}
