import Foundation

/// Immutable geometry in ARKit world coordinates, measured in meters.
struct ScannedMesh: Sendable {
    var vertices: [SIMD3<Float>]
    var triangles: [SIMD3<UInt32>]
    static let empty = ScannedMesh(vertices: [], triangles: [])

    var isValid: Bool {
        !vertices.isEmpty && !triangles.isEmpty &&
        vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite } &&
        triangles.allSatisfy {
            Int($0.x) < vertices.count && Int($0.y) < vertices.count && Int($0.z) < vertices.count
        }
    }

    static func merging(_ parts: [ScannedMesh]) -> ScannedMesh {
        var result = ScannedMesh.empty
        for part in parts where part.isValid {
            let offset = UInt32(result.vertices.count)
            result.vertices.append(contentsOf: part.vertices)
            result.triangles.append(contentsOf: part.triangles.map {
                SIMD3($0.x + offset, $0.y + offset, $0.z + offset)
            })
        }
        return result
    }
}
