import Foundation

enum AnimationPreset: String, CaseIterable, Identifiable {
    case fluid  = "fluid"
    case smoke  = "smoke"
    case flow   = "flow"
    case lava   = "lava"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fluid: return "〰  Fluid"
        case .smoke: return "◌  Smoke"
        case .flow:  return "∿  Flow"
        case .lava:  return "●  Lava"
        }
    }
}

class AnimationController: ObservableObject {
    @Published var currentPreset: AnimationPreset = .fluid
    @Published var speed: Double = 1.0
    @Published var isRunning: Bool = true

    var time: Float = 0.0

    func tick(delta: Float) {
        guard isRunning else { return }
        time += delta * Float(speed)
    }
}
