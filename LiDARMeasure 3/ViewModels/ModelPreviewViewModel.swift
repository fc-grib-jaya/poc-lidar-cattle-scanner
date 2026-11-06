import SwiftUI

@MainActor
final class ModelPreviewViewModel: ObservableObject {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case solid = "Solid"
        case wireframe = "Wireframe"
        var id: String { rawValue }
    }
    @Published var displayMode: DisplayMode = .solid
    @Published private(set) var cameraResetID = UUID()
    func resetCamera() { cameraResetID = UUID() }
}
