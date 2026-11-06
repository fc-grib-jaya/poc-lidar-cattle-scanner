import SwiftUI
import UniformTypeIdentifiers

struct MeasurementView: View {
    @StateObject private var model = MeasurementViewModel()
    @StateObject private var scan = ScanViewModel()
    @State private var isImporterPresented = false
    @State private var importError: String?

    var body: some View {
        ZStack {
            ARMeasurementView(model: model, scan: scan).ignoresSafeArea()
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LiDAR Measure • PoC").font(.headline)
                    Text(model.status).font(.subheadline)
                    Text("Ketuk 2 titik di benda diam • jarak 0,2–3 m")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Tampilkan mesh 3D", isOn: $model.showMesh)
                        .font(.caption)
                }
                .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                VStack(spacing: 8) {
                    Text(scan.message).font(.caption)
                    if scan.isScanning { Text("\(scan.triangleCount) segitiga") }
                    HStack {
                        if scan.isScanning {
                            Button("Selesai scan") { scan.finish() }
                        } else {
                            Button("Mulai scan") { scan.begin() }.disabled(scan.isExporting || scan.isImporting)
                        }
                        if scan.mesh != nil {
                            Button("Preview 3D") { scan.isPreviewPresented = true }
                        }
                    }.buttonStyle(.borderedProminent)
                }
                .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                Button(scan.isImporting ? "Membuka OBJ…" : "Buka OBJ dari Files") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(scan.isScanning || scan.isExporting || scan.isImporting)
                if !model.measurements.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(model.measurements.enumerated()), id: \.element.id) { index, item in
                                Text("#\(index + 1)  \(item.label)")
                                    .padding(10).background(.regularMaterial, in: Capsule())
                            }
                        }
                    }
                }
                HStack {
                    Button("Batalkan terakhir") { model.undo() }
                    Spacer()
                    Button("Reset scan", role: .destructive) { model.reset() }.disabled(scan.isExporting || scan.isImporting)
                }
                .buttonStyle(.borderedProminent)
            }.padding()
        }
        .sheet(isPresented: $scan.isPreviewPresented) {
            ModelPreviewView(model: scan).id(scan.previewID)
        }
        .fileImporter(isPresented: $isImporterPresented,
                      allowedContentTypes: [UTType(filenameExtension: "obj") ?? .data]) { result in
            switch result {
            case .success(let url): scan.openOBJ(url)
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .alert("Gagal membuka file", isPresented: Binding(
            get: { importError != nil }, set: { if !$0 { importError = nil } }
        )) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
    }
}
