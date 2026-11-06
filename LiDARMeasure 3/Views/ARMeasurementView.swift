import ARKit
import RealityKit
import SwiftUI
import AVFoundation

struct ARMeasurementView: UIViewRepresentable {
    @ObservedObject var model: MeasurementViewModel
    @ObservedObject var scan: ScanViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model, scan: scan) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        context.coordinator.view = view
        view.session.delegate = context.coordinator
        view.session.delegateQueue = .main
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.tap(_:))))
        context.coordinator.requestStart()
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.resetID != model.resetID {
            coordinator.resetID = model.resetID
            scan.reset()
            coordinator.start()
        }
        uiView.debugOptions = model.showMesh ? [.showSceneUnderstanding] : []
        coordinator.render()
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.active = false
        uiView.session.pause()
        uiView.session.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        weak var view: ARView?
        let model: MeasurementViewModel
        let scan: ScanViewModel
        var resetID: UUID
        var active = true
        private var wasScanning = false
        private var renderedIDs: [UUID] = []
        private var renderedPending: SIMD3<Float>?
        private let content = AnchorEntity(world: .zero)

        init(model: MeasurementViewModel, scan: ScanViewModel) {
            self.scan = scan
            self.model = model
            self.resetID = model.resetID
        }

        func requestStart() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: start()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self, self.active else { return }
                        if granted { self.start() }
                        else { self.model.status = "Izinkan kamera lewat Settings untuk memulai." }
                    }
                }
            default: model.status = "Izinkan kamera lewat Settings untuk memulai."
            }
        }

        func start() {
            guard active, AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  let view else { return }
            guard ARWorldTrackingConfiguration.isSupported,
                  ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth),
                  ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
                model.status = "Perangkat tidak mendukung LiDAR. Gunakan iPhone/iPad ber-LiDAR fisik."
                return
            }
            let configuration = ARWorldTrackingConfiguration()
            configuration.frameSemantics = .sceneDepth
            configuration.sceneReconstruction = .mesh
            view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            if content.scene == nil { view.scene.addAnchor(content) }
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let view, let frame = view.session.currentFrame,
                  case .normal = frame.camera.trackingState else {
                model.status = "Tracking belum siap. Gerakkan perangkat perlahan."
                return
            }
            guard let orientation = view.window?.windowScene?.interfaceOrientation,
                  let point = DepthSampler.worldPoint(at: gesture.location(in: view),
                       viewport: view.bounds.size, orientation: orientation, frame: frame) else {
                model.status = "Depth belum valid. Bidik permukaan solid pada jarak 0,2–3 m."
                return
            }
            model.select(point)
        }

        func render() {
            let ids = model.measurements.map(\.id)
            guard ids != renderedIDs || model.pendingPoint != renderedPending else { return }
            renderedIDs = ids
            renderedPending = model.pendingPoint
            for child in Array(content.children) { child.removeFromParent() }
            for measurement in model.measurements {
                marker(measurement.start)
                marker(measurement.end)
                let delta = measurement.end - measurement.start
                let line = ModelEntity(mesh: .generateBox(size: SIMD3(0.003, 0.003, measurement.meters)),
                                       materials: [UnlitMaterial(color: .systemYellow)])
                line.position = (measurement.start + measurement.end) / 2
                line.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(delta))
                content.addChild(line)
            }
            if let point = model.pendingPoint { marker(point) }
        }

        private func marker(_ point: SIMD3<Float>) {
            let entity = ModelEntity(mesh: .generateSphere(radius: 0.006),
                                     materials: [UnlitMaterial(color: .systemYellow)])
            entity.position = point
            content.addChild(entity)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if scan.isScanning && !wasScanning {
                scan.receive { $0.update(frame.anchors) }
            }
            wasScanning = scan.isScanning
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            scan.receive { $0.update(anchors) }
        }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            scan.receive { $0.update(anchors) }
        }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            scan.receive { $0.remove(anchors) }
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .normal: model.status = "Siap. Ketuk dua titik pada permukaan benda."
            case .notAvailable: model.status = "Tracking tidak tersedia."
            case .limited: model.status = "Tracking terbatas. Gerakkan perlahan di area cukup terang."
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            if scan.isScanning { scan.finish() }
            model.status = "Sesi gagal: \(error.localizedDescription). Coba Reset scan."
        }
        func sessionWasInterrupted(_ session: ARSession) {
            if scan.isScanning { scan.finish() }
            model.status = "Sesi terhenti sementara."
        }
        func sessionInterruptionEnded(_ session: ARSession) { model.reset() }
    }
}
