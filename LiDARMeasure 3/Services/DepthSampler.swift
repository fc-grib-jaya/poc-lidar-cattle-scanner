import ARKit
import UIKit

/// Reads actual LiDAR depth; never substitutes a guessed plane.
enum DepthSampler {
    static func worldPoint(at location: CGPoint, viewport: CGSize,
                           orientation: UIInterfaceOrientation, frame: ARFrame) -> SIMD3<Float>? {
        guard viewport.width > 0, viewport.height > 0,
              let depth = frame.sceneDepth else { return nil }
        let viewPoint = CGPoint(x: location.x / viewport.width, y: location.y / viewport.height)
        let imagePoint = viewPoint.applying(frame.displayTransform(for: orientation,
                                              viewportSize: viewport).inverted())
        guard imagePoint.x >= 0, imagePoint.x < 1,
              imagePoint.y >= 0, imagePoint.y < 1 else { return nil }
        let map = depth.depthMap
        guard CVPixelBufferGetPixelFormatType(map) == kCVPixelFormatType_DepthFloat32,
              let confidence = depth.confidenceMap else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(confidence, .readOnly)
            CVPixelBufferUnlockBaseAddress(map, .readOnly)
        }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let x = min(width - 1, Int(imagePoint.x * CGFloat(width)))
        let y = min(height - 1, Int(imagePoint.y * CGFloat(height)))
        guard let base = CVPixelBufferGetBaseAddress(map),
              let confidenceBase = CVPixelBufferGetBaseAddress(confidence),
              CVPixelBufferGetWidth(confidence) == width,
              CVPixelBufferGetHeight(confidence) == height else { return nil }
        let quality = confidenceBase.advanced(by: y * CVPixelBufferGetBytesPerRow(confidence))
            .assumingMemoryBound(to: UInt8.self)[x]
        guard quality >= UInt8(ARConfidenceLevel.medium.rawValue) else { return nil }
        let z = base.advanced(by: y * CVPixelBufferGetBytesPerRow(map))
            .assumingMemoryBound(to: Float.self)[x]
        guard z.isFinite, z >= 0.2, z <= 3.0 else { return nil }
        let resolution = frame.camera.imageResolution
        // Depth pixel centers expressed in captured-image pixels.
        let u = (Float(x) + 0.5) * Float(resolution.width) / Float(width)
        let v = (Float(y) + 0.5) * Float(resolution.height) / Float(height)
        let k = frame.camera.intrinsics
        // Camera image: +y down, +z forward. ARKit camera: +y up, -z forward.
        let cameraPoint = SIMD4<Float>((u - k[2][0]) * z / k[0][0],
                                      -(v - k[2][1]) * z / k[1][1], -z, 1)
        let world = frame.camera.transform * cameraPoint
        return SIMD3(world.x, world.y, world.z)
    }
}
