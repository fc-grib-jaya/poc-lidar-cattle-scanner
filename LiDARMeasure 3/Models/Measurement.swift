import Foundation
import simd

struct Measurement: Identifiable {
    let id = UUID()
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    var meters: Float { simd_distance(start, end) }
    var label: String { String(format: "%.1f cm", meters * 100) }
}
