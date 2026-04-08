import Foundation
import Combine

enum AnimationPreset: String, CaseIterable, Identifiable {
    case particles = "particles"
    case aurora = "aurora"
    case nebula = "nebula"
    case wave = "wave"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .particles: return "✦  Particles"
        case .aurora:    return "〜  Aurora"
        case .nebula:    return "◉  Nebula"
        case .wave:      return "≋  Wave"
        }
    }
}

class AnimationController: ObservableObject {
    @Published var currentPreset: AnimationPreset = .particles
    @Published var speed: Double = 1.0
    @Published var isRunning: Bool = true

    var time: Float = 0.0

    func tick(delta: Float) {
        guard isRunning else { return }
        time += delta * Float(speed)
    }
}
