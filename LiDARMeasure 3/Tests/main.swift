import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
let triangle = ScannedMesh(vertices: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
                           triangles: [SIMD3(0, 1, 2)])
check(triangle.isValid, "Valid triangle rejected")
let merged = ScannedMesh.merging([triangle, triangle])
check(merged.vertices.count == 6, "Vertices missing")
check(merged.triangles[1] == SIMD3(3, 4, 5), "Merged indices were not rebased")
check(!ScannedMesh.empty.isValid, "Empty scan accepted")
let invalid = ScannedMesh(vertices: triangle.vertices, triangles: [SIMD3(0, 1, 3)])
check(!invalid.isValid, "Out-of-range face accepted")
let nan = ScannedMesh(vertices: [SIMD3(Float.nan, 0, 0)], triangles: [SIMD3(0, 0, 0)])
check(!nan.isValid, "NaN vertex accepted")
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: directory) }
let url = try OBJExportService.write(merged, directory: directory)
let text = try String(contentsOf: url, encoding: .utf8)
check(text.contains("f 1 2 3\n"), "OBJ must use 1-based indices")
check(text.contains("f 4 5 6\n"), "OBJ second part indices incorrect")
check(text.contains("v 1.0 0.0 0.0\n"), "Meter scale changed")
check(text.split(separator: "\n").filter { $0.hasPrefix("v ") }.count == 6, "Wrong OBJ vertex count")
let secondURL = try OBJExportService.write(triangle, directory: directory)
check(url != secondURL, "Exports overwrite each other")
do {
    _ = try OBJExportService.write(invalid, directory: directory)
    preconditionFailure("Invalid export should throw")
} catch OBJExportService.ExportError.invalidMesh { }
print("PASS: mesh validation, merge offsets, OBJ indices, metric coordinates, unique files, invalid export")

let imported = try OBJImportService.read(url)
check(imported.vertices == merged.vertices, "Round-trip changed coordinates")
check(imported.triangles == merged.triangles, "Round-trip changed faces")
let invalidFiles = ["v nan 0 0\nf 1 1 1", "v 0 0 0\nf 0 1 1", "v 0 0 0\nf 1 2 3", "v 0 0 0\nf 1/1 1/1 1/1", ""]
for invalidFile in invalidFiles {
    do {
        _ = try OBJImportService.decode(invalidFile)
        preconditionFailure("Invalid OBJ accepted")
    } catch OBJImportService.ImportError.unsupported { }
}
print("PASS: OBJ export/import round-trip and malformed/unsupported file rejection")
