import Foundation
import Combine

enum NotchState: Equatable {
    case closed
    case peek(PeekContent)
    case expanded
}

/// Fingers moving left = `.left` (next track).
enum SwipeDirection: Equatable {
    case left, right
}

struct NotchConfiguration: Equatable {
    var hoverDelay: TimeInterval = 0.1
    var peekDuration: TimeInterval = 3.0
    var hudDuration: TimeInterval = 1.5
    var collapseDelay: TimeInterval = 0.3
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .closed
    @Published private(set) var media: MediaState?
    /// HUD value shown as a small row while expanded.
    @Published private(set) var expandedHUD: HUDState?

    var configuration = NotchConfiguration()
    var mediaCommandHandler: ((MediaCommand) -> Void)?

    private let scheduler: Scheduler
    private var pending: PeekContent?
    private var peekToken: SchedulerToken?
    private var hoverToken: SchedulerToken?
    private var expandedHUDToken: SchedulerToken?
    private var isHovering = false

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    func present(_ content: PeekContent) {
        switch state {
        case .expanded:
            if case .hud(let hud) = content { showExpandedHUD(hud) }
        case .peek(let current):
            if content.priority >= current.priority {
                showPeek(content)
            } else {
                pending = content
            }
        case .closed:
            showPeek(content)
        }
    }

    func hoverChanged(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        hoverToken?.cancel()
        hoverToken = nil
        if hovering {
            guard state != .expanded else { return }
            hoverToken = scheduler.schedule(after: configuration.hoverDelay) { [weak self] in self?.expand() }
        } else if state == .expanded {
            hoverToken = scheduler.schedule(after: configuration.collapseDelay) { [weak self] in self?.collapse() }
        }
    }

    func updateMedia(_ media: MediaState?) {
        self.media = media
    }

    func handleSwipe(_ direction: SwipeDirection) {
        guard state == .expanded, media != nil else { return }
        mediaCommandHandler?(direction == .left ? .next : .previous)
    }

    func send(_ command: MediaCommand) {
        mediaCommandHandler?(command)
    }

    private func showPeek(_ content: PeekContent) {
        peekToken?.cancel()
        state = .peek(content)
        let duration = content.isHUD ? configuration.hudDuration : configuration.peekDuration
        peekToken = scheduler.schedule(after: duration) { [weak self] in self?.peekFinished() }
    }

    private func peekFinished() {
        peekToken = nil
        if let next = pending {
            pending = nil
            showPeek(next)
        } else {
            state = .closed
        }
    }

    private func expand() {
        hoverToken = nil
        peekToken?.cancel()
        peekToken = nil
        pending = nil
        state = .expanded
    }

    private func collapse() {
        hoverToken = nil
        expandedHUDToken?.cancel()
        expandedHUDToken = nil
        expandedHUD = nil
        state = .closed
    }

    private func showExpandedHUD(_ hud: HUDState) {
        expandedHUD = hud
        expandedHUDToken?.cancel()
        expandedHUDToken = scheduler.schedule(after: configuration.hudDuration) { [weak self] in
            self?.expandedHUD = nil
        }
    }
}
