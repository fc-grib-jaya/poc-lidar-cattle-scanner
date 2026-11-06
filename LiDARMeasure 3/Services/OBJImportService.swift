import Foundation

/// Reader for the meter-based, triangle-only OBJ files exported by this PoC.
/// Materials, textures, polygons, negative indices, and other OBJ dialects are not supported.
enum OBJImportService {
    enum ImportError: LocalizedError {
        case unsupported
        var errorDescription: String? { "OBJ tidak valid atau format belum didukung. Pilih OBJ hasil ekspor aplikasi ini." }
    }
    static func read(_ url: URL) throws -> ScannedMesh {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? Int.max) <= 100_000_000 else { throw ImportError.unsupported }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try decode(text)
    }
    static func decode(_ text: String) throws -> ScannedMesh {
        var mesh = ScannedMesh.empty
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let kind = fields.first else { continue }
            if kind.hasPrefix("#") || kind == "o" || kind == "g" || kind == "s" { continue }
            if kind == "v" {
                guard fields.count == 4, let x = Float(fields[1]), let y = Float(fields[2]),
                      let z = Float(fields[3]), x.isFinite, y.isFinite, z.isFinite,
                      mesh.vertices.count < 1_000_000 else { throw ImportError.unsupported }
                mesh.vertices.append(SIMD3(x, y, z))
            } else if kind == "f" {
                guard fields.count == 4, let a = UInt32(fields[1]), let b = UInt32(fields[2]),
                      let c = UInt32(fields[3]), a > 0, b > 0, c > 0,
                      mesh.triangles.count < 500_000 else { throw ImportError.unsupported }
                mesh.triangles.append(SIMD3(a - 1, b - 1, c - 1))
            } else { throw ImportError.unsupported }
        }
        guard mesh.isValid else { throw ImportError.unsupported }
        return mesh
    }
}
