import UIKit

/// Tactile feedback for every meaningful moment. Each call is cheap and a
/// no-op when haptics are disabled in settings.
@MainActor
final class HapticsManager {
    var isEnabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        notification.prepare()
    }

    func letterSelected() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.7)
    }

    func letterRemoved() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.4)
    }

    func solved(length: Int) {
        guard isEnabled else { return }
        if length >= 7 {
            heavy.impactOccurred()
        } else {
            medium.impactOccurred(intensity: 0.6 + 0.08 * CGFloat(length - 3))
        }
    }

    func milestone() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func rejected() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    func danger() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.6)
    }

    func missed() {
        guard isEnabled else { return }
        heavy.impactOccurred(intensity: 1.0)
    }
}
