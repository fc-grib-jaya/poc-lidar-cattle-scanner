import SceneKit
import simd
import SwiftUI

struct ModelPreviewView: View {
    @ObservedObject var model: ScanViewModel
    @StateObject private var viewer = ModelPreviewViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let mesh = model.mesh {
                    MeshSceneView(mesh: mesh, mode: viewer.displayMode, resetID: viewer.cameraResetID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Picker("Tampilan model", selection: $viewer.displayMode) {
                        ForEach(ModelPreviewViewModel.DisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }.pickerStyle(.segmented).padding(.horizontal)
                    Button("Reset kamera") { viewer.resetCamera() }
                    Text("\(mesh.vertices.count) titik • \(mesh.triangles.count) segitiga")
                        .font(.caption.monospacedDigit())
                    Text("Geser untuk putar • cubit untuk zoom • koordinat dalam meter")
                        .font(.caption)
                }
                Text(model.message).font(.caption).padding(.horizontal)
                if let url = model.exportURL {
                    ShareLink(item: url) { Label("Bagikan OBJ", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(model.isExporting ? "Mengekspor…" : "Export OBJ") { model.export() }
                        .buttonStyle(.borderedProminent).disabled(model.isExporting)
                }
                Text("Geometri tanpa tekstur foto. Lingkungan dapat ikut terscan.")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom)
            }
            .navigationTitle("Model 3D")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Tutup") { dismiss() }.disabled(model.isExporting) }
        }
        .interactiveDismissDisabled(model.isExporting)
    }
}

private struct MeshSceneView: UIViewRepresentable {
    let mesh: ScannedMesh
    let mode: ModelPreviewViewModel.DisplayMode
    let resetID: UUID

    final class Coordinator {
        var resetID: UUID?
        var camera: SCNNode?
        var center = SIMD3<Float>.zero
        var initialPosition = SIMD3<Float>.zero
        var material: SCNMaterial?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        // Expand triangles to give each face its own normal (flat-shaded mesh).
        var points: [SCNVector3] = []
        var normals: [SCNVector3] = []
        points.reserveCapacity(mesh.triangles.count * 3)
        normals.reserveCapacity(mesh.triangles.count * 3)
        for face in mesh.triangles {
            let a = mesh.vertices[Int(face.x)]
            let b = mesh.vertices[Int(face.y)]
            let c = mesh.vertices[Int(face.z)]
            let cross = simd_cross(b - a, c - a)
            let normal = simd_length_squared(cross) > 1e-12 ? simd_normalize(cross) : SIMD3<Float>(0, 1, 0)
            for point in [a, b, c] {
                points.append(SCNVector3(point.x, point.y, point.z))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
            }
        }
        let indices = Array(0..<UInt32(points.count))
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: points),
                                            SCNGeometrySource(normals: normals)],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.72, alpha: 1)
        material.isDoubleSided = true
        material.lightingModel = .lambert
        geometry.materials = [material]
        context.coordinator.material = material
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        var minimum = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        for v in mesh.vertices {
            minimum = SIMD3(min(minimum.x, v.x), min(minimum.y, v.y), min(minimum.z, v.z))
            maximum = SIMD3(max(maximum.x, v.x), max(maximum.y, v.y), max(maximum.z, v.z))
        }
        let center = (minimum + maximum) / 2
        let radius = max(simd_length(maximum - minimum) / 2, 0.05)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.001
        camera.camera?.zFar = Double(max(radius * 20, 100))
        context.coordinator.camera = camera
        context.coordinator.center = center
        context.coordinator.initialPosition = center + SIMD3(0, radius * 0.4, radius * 3.5)
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 900
        keyLight.position = SCNVector3(0, radius, 0)
        camera.addChildNode(keyLight)
        view.scene = scene
        view.pointOfView = camera
        view.allowsCameraControl = true
        view.defaultCameraController.target = SCNVector3(center.x, center.y, center.z)
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)
        view.antialiasingMode = .multisampling4X
        apply(view, coordinator: context.coordinator)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        apply(view, coordinator: context.coordinator)
    }
    private func apply(_ view: SCNView, coordinator: Coordinator) {
        coordinator.material?.fillMode = mode == .wireframe ? .lines : .fill
        if coordinator.resetID != resetID, let camera = coordinator.camera {
            coordinator.resetID = resetID
            view.defaultCameraController.stopInertia()
            camera.simdPosition = coordinator.initialPosition
            let center = coordinator.center
            camera.look(at: SCNVector3(center.x, center.y, center.z))
            view.pointOfView = camera
            view.defaultCameraController.pointOfView = camera
            view.defaultCameraController.target = SCNVector3(center.x, center.y, center.z)
        }
    }
}

#Preview{
    ModelPreviewView(model: ScanViewModel())
}
