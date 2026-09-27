import Foundation
import Observation

/// Player preferences, stored in UserDefaults so they're available instantly at launch.
@MainActor
@Observable
final class GameSettings {
    private enum Key {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
        static let swipe = "settings.swipeInputEnabled"
        static let keyboard = "settings.keyboardInputEnabled"
        static let showKeyboard = "settings.showKeyboard"
        static let reducedMotion = "settings.reducedMotion"
    }

    private let defaults: UserDefaults

    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.sound) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }
    var swipeInputEnabled: Bool { didSet { defaults.set(swipeInputEnabled, forKey: Key.swipe) } }
    var keyboardInputEnabled: Bool { didSet { defaults.set(keyboardInputEnabled, forKey: Key.keyboard) } }
    /// Remembers whether the player last played with the system keyboard up.
    var showKeyboard: Bool { didSet { defaults.set(showKeyboard, forKey: Key.showKeyboard) } }
    var reducedMotion: Bool { didSet { defaults.set(reducedMotion, forKey: Key.reducedMotion) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.sound: true,
            Key.haptics: true,
            Key.swipe: true,
            Key.keyboard: true,
            Key.showKeyboard: false,
            Key.reducedMotion: false,
        ])
        soundEnabled = defaults.bool(forKey: Key.sound)
        hapticsEnabled = defaults.bool(forKey: Key.haptics)
        swipeInputEnabled = defaults.bool(forKey: Key.swipe)
        keyboardInputEnabled = defaults.bool(forKey: Key.keyboard)
        showKeyboard = defaults.bool(forKey: Key.showKeyboard)
        reducedMotion = defaults.bool(forKey: Key.reducedMotion)
    }
}
