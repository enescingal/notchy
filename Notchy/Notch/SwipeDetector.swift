import CoreGraphics

/// Turns a stream of horizontal trackpad scroll deltas into at most one swipe per gesture.
struct SwipeDetector {
    enum Phase { case began, changed, ended }

    var threshold: CGFloat = 40
    private var accumulated: CGFloat = 0
    private var fired = false

    /// `fingerDeltaX` is positive when the fingers move right.
    mutating func process(phase: Phase, fingerDeltaX: CGFloat) -> SwipeDirection? {
        switch phase {
        case .began:
            accumulated = fingerDeltaX
            fired = false
        case .changed:
            accumulated += fingerDeltaX
        case .ended:
            accumulated = 0
            fired = false
            return nil
        }
        guard !fired, abs(accumulated) >= threshold else { return nil }
        fired = true
        return accumulated < 0 ? .left : .right
    }
}
