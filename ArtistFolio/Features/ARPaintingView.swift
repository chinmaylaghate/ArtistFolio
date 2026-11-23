import SwiftUI
import ARKit
import RealityKit

struct ARPaintingView: View {
    let imageURL: URL?
    let dimensions: ArtworkDimensions

    @State private var message = "Point at a wall, then tap to hang"
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
                    .padding(.bottom, 88)
                    .allowsHitTesting(false)
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
        coaching.isUserInteractionEnabled = false
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
        var imageAspect: CGFloat?
        var placedTransform: simd_float4x4?

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
                imageAspect = CGFloat(cg.width) / CGFloat(cg.height)
                if let placedTransform { placeArtwork(at: placedTransform) }
            }
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let pt = gesture.location(in: arView)
            guard let hit = arView.raycast(from: pt, allowing: .estimatedPlane, alignment: .vertical).first else {
                parent.message = "No wall detected here — try a different spot"
                return
            }
            placeArtwork(at: wallTransform(from: hit.worldTransform, cameraPosition: arView.cameraTransform.translation))
        }

        // Plane hits use +Y as the wall normal with an arbitrary roll, so rebuild the basis to keep the art level.
        private func wallTransform(from hit: simd_float4x4, cameraPosition: SIMD3<Float>) -> simd_float4x4 {
            let position = simd_make_float3(hit.columns.3)
            var normal = simd_make_float3(hit.columns.1)
            normal.y = 0
            normal = simd_normalize(normal)
            if simd_dot(normal, cameraPosition - position) < 0 { normal = -normal }
            let up = SIMD3<Float>(0, 1, 0)
            let right = simd_normalize(simd_cross(up, normal))
            return simd_float4x4(SIMD4(right, 0), SIMD4(normal, 0), SIMD4(-up, 0), hit.columns.3)
        }

        func placeArtwork(at transform: simd_float4x4) {
            guard let arView else { return }
            currentAnchor?.removeFromParent()
            placedTransform = transform

            let cm = parent.dimensions.sizeInCentimeters(matching: imageAspect)
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
            frameEnt.position.y = 0.003
            canvasEnt.position.y = 0.005

            let group = Entity()
            group.addChild(frameEnt)
            group.addChild(canvasEnt)

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
