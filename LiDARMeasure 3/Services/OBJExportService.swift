import Foundation

enum OBJExportService {
    enum ExportError: LocalizedError {
        case invalidMesh
        var errorDescription: String? { "Mesh kosong atau tidak valid. Ulangi scan." }
    }

    /// OBJ is unitless; coordinates are written in meters, Y-up, without rescaling.
    static func write(_ mesh: ScannedMesh, directory: URL) throws -> URL {
        guard mesh.isValid else { throw ExportError.invalidMesh }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("LiDAR-\(UUID().uuidString).obj")
        var obj = "# LiDAR Measure: 1 unit = 1 meter; Y-up; no texture\no LiDARScan\n"
        // Swift's numeric interpolation uses a decimal point independent of locale.
        for v in mesh.vertices { obj += "v \(v.x) \(v.y) \(v.z)\n" }
        for t in mesh.triangles { obj += "f \(t.x + 1) \(t.y + 1) \(t.z + 1)\n" }
        try obj.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
