import SwiftUI
import simd

@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published private(set) var measurements: [Measurement] = []
    @Published private(set) var pendingPoint: SIMD3<Float>?
    @Published var status = "Gerakkan perangkat perlahan untuk memulai."
    @Published var showMesh = false
    @Published var resetID = UUID()

    func select(_ point: SIMD3<Float>) {
        if let start = pendingPoint {
            guard simd_distance(start, point) > 0.005 else {
                status = "Titik terlalu dekat. Pilih ujung benda yang lain."
                return
            }
            measurements.append(Measurement(start: start, end: point))
            pendingPoint = nil
            status = "Ukuran tersimpan. Ketuk dua titik untuk ukuran berikutnya."
        } else {
            pendingPoint = point
            status = "Titik pertama dipilih. Ketuk titik kedua."
        }
    }

    func undo() {
        if pendingPoint != nil { pendingPoint = nil }
        else if !measurements.isEmpty { measurements.removeLast() }
        status = "Ketuk permukaan benda untuk memilih titik."
    }

    func reset() {
        measurements.removeAll()
        pendingPoint = nil
        resetID = UUID()
        status = "Pindai ulang benda sebelum memilih titik."
    }
}
