import AppKit
import SwiftUI

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onSwipe: (SwipeDirection) -> Void = { _ in }
    private var swipe = SwipeDetector()

    /// Buttons must work on the first click even though the panel never becomes key.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let phase: SwipeDetector.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            return // momentum or a classic mouse wheel
        }
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        if let direction = swipe.process(phase: phase, fingerDeltaX: fingerDeltaX) {
            onSwipe(direction)
        }
    }
}
