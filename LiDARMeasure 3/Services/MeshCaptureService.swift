import ARKit
import Metal

/// Called on the main queue by the AR adapter. Copy buffers immediately: do not
/// keep mutable ARKit/Metal buffers as the saved scan.
@MainActor
final class MeshCaptureService {
    private var parts: [UUID: ScannedMesh] = [:]
    var triangleCount: Int { parts.values.reduce(0) { $0 + $1.triangles.count } }
    func clear() { parts.removeAll() }
    func remove(_ anchors: [ARAnchor]) {
        for anchor in anchors { parts.removeValue(forKey: anchor.identifier) }
    }
    func update(_ anchors: [ARAnchor]) {
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            if let mesh = copy(anchor) { parts[anchor.identifier] = mesh }
        }
    }
    func snapshot() -> ScannedMesh {
        ScannedMesh.merging(parts.keys.sorted { $0.uuidString < $1.uuidString }.compactMap { parts[$0] })
    }

    private func copy(_ anchor: ARMeshAnchor) -> ScannedMesh? {
        let geometry = anchor.geometry
        let source = geometry.vertices
        let faces = geometry.faces
        guard source.format == .float3, faces.indexCountPerPrimitive == 3,
              [2, 4].contains(faces.bytesPerIndex) else { return nil }
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(source.count)
        for index in 0..<source.count {
            let address = source.buffer.contents().advanced(by: source.offset + index * source.stride)
            // float3 is 12 bytes in the buffer, while Swift SIMD3 can occupy 16.
            let coordinates = address.assumingMemoryBound(to: Float.self)
            let world = anchor.transform * SIMD4(coordinates[0], coordinates[1], coordinates[2], 1)
            vertices.append(SIMD3(world.x, world.y, world.z))
        }
        let indices = faces.buffer.contents()
        func index(_ position: Int) -> UInt32 {
            let address = indices.advanced(by: position * faces.bytesPerIndex)
            if faces.bytesPerIndex == 2 { return UInt32(address.load(as: UInt16.self)) }
            return address.load(as: UInt32.self)
        }
        var triangles: [SIMD3<UInt32>] = []
        triangles.reserveCapacity(faces.count)
        for face in 0..<faces.count {
            triangles.append(SIMD3(index(face * 3), index(face * 3 + 1), index(face * 3 + 2)))
        }
        let mesh = ScannedMesh(vertices: vertices, triangles: triangles)
        return mesh.isValid ? mesh : nil
    }
}
