import SwiftUI

@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var previewID = UUID()
    @Published private(set) var isImporting = false
    @Published private(set) var isScanning = false
    @Published private(set) var triangleCount = 0
    @Published private(set) var mesh: ScannedMesh?
    @Published private(set) var exportURL: URL?
    @Published private(set) var isExporting = false
    @Published var isPreviewPresented = false
    @Published private(set) var message = "Scan singkat: mesh lingkungan ikut tersimpan."
    private let capture = MeshCaptureService()
    private var generation = UUID()

    func begin() {
        generation = UUID()
        capture.clear()
        triangleCount = 0
        mesh = nil
        exportURL = nil
        isScanning = true
        message = "Kelilingi benda diam perlahan, lalu tekan Selesai."
    }
    func finish() {
        guard isScanning else { return }
        isScanning = false
        let result = capture.snapshot()
        capture.clear()
        guard result.isValid else {
            message = "Belum ada mesh. Pastikan LiDAR aktif dan scan permukaan solid."
            return
        }
        mesh = result
        previewID = UUID()
        message = "Model dibekukan. Preview atau ekspor OBJ."
        isPreviewPresented = true
    }
    func reset() {
        generation = UUID()
        isScanning = false
        capture.clear()
        triangleCount = 0
        mesh = nil
        exportURL = nil
        isPreviewPresented = false
        message = "Scan direset. Mulai scan baru."
    }
    // The adapter passes platform data through this service, keeping ARSession out
    // of the ViewModel. Called after the service receives an anchor event.
    func receive(_ event: (MeshCaptureService) -> Void) {
        guard isScanning else { return }
        event(capture)
        triangleCount = capture.triangleCount
        if triangleCount > 300_000 {
            finish()
            message = "Batas PoC tercapai; scan diselesaikan otomatis."
        }
    }
    func openOBJ(_ url: URL) {
        guard !isImporting, !isExporting, !isScanning else { return }
        isImporting = true
        let requestGeneration = generation
        message = "Membuka OBJ…"
        Task {
            defer { isImporting = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try OBJImportService.read(url)
                }.value
                guard requestGeneration == generation else { return }
                mesh = result
                exportURL = nil
                previewID = UUID()
                message = "OBJ dibuka. Koordinat dibaca sebagai meter."
                isPreviewPresented = true
            } catch {
                guard requestGeneration == generation else { return }
                message = "Gagal membuka: \(error.localizedDescription)"
            }
        }
    }

    func export() {
        guard let mesh, !isExporting else { return }
        isExporting = true
        let exportGeneration = generation
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scans", isDirectory: true)
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try OBJExportService.write(mesh, directory: directory)
                }.value
                guard generation == exportGeneration else {
                    isExporting = false
                    return
                }
                exportURL = url
                message = "OBJ tersimpan. Gunakan Bagikan untuk Files atau AirDrop."
            } catch { message = "Ekspor gagal: \(error.localizedDescription)" }
            isExporting = false
        }
    }
}
