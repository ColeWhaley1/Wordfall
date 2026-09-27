import QuartzCore

/// Calls `onFrame` with the elapsed seconds on every screen refresh.
/// This is the game clock: the engine advances by real elapsed time, so
/// gameplay speed doesn't depend on the device's frame rate.
@MainActor
final class DisplayLink: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onFrame: (TimeInterval) -> Void

    init(onFrame: @escaping (TimeInterval) -> Void) {
        self.onFrame = onFrame
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        if let lastTimestamp {
            onFrame(now - lastTimestamp)
        }
        lastTimestamp = now
    }
}
