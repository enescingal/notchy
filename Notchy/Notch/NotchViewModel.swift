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
    var timerDoneDuration: TimeInterval = 5.0
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .closed
    @Published private(set) var media: MediaState?
    /// HUD value shown as a small row while expanded.
    @Published private(set) var expandedHUD: HUDState?
    /// Quick controls the row can use right now; the others are drawn dimmed.
    @Published var availableControls: Set<QuickControl> = []
    /// The running or paused countdown, if any.
    @Published private(set) var countdown: CountdownState?
    /// True while the minutes field is open; keeps the island expanded and takes the keyboard.
    @Published private(set) var isEditingCountdown = false

    var configuration = NotchConfiguration()
    var mediaCommandHandler: ((MediaCommand) -> Void)?
    var controlHandler: ((QuickControl) -> Void)?
    /// Plays the done sound; set by the app so the view model stays free of AppKit.
    var onCountdownFinished: (() -> Void)?

    private let scheduler: Scheduler
    private var pending: PeekContent?
    private var peekToken: SchedulerToken?
    private var hoverToken: SchedulerToken?
    private var expandedHUDToken: SchedulerToken?
    private var isHovering = false
    private let now: () -> Date
    private var countdownToken: SchedulerToken?

    init(scheduler: Scheduler, now: @escaping () -> Date = Date.init) {
        self.scheduler = scheduler
        self.now = now
    }

    /// What the island shows besides its state; drives its size.
    var islandContent: IslandContent {
        IslandContent(isMediaPlaying: media?.isPlaying == true, hasMedia: media != nil,
                      hasCountdown: countdown != nil)
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
        } else if state == .expanded, !isEditingCountdown {
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

    func perform(_ control: QuickControl) {
        controlHandler?(control)
    }

    private func showPeek(_ content: PeekContent) {
        peekToken?.cancel()
        state = .peek(content)
        let duration: TimeInterval
        switch content {
        case .hud: duration = configuration.hudDuration
        case .timerDone: duration = configuration.timerDoneDuration
        case .battery, .bluetooth: duration = configuration.peekDuration
        }
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
        isEditingCountdown = false
        state = .closed
    }

    private func showExpandedHUD(_ hud: HUDState) {
        expandedHUD = hud
        expandedHUDToken?.cancel()
        expandedHUDToken = scheduler.schedule(after: configuration.hudDuration) { [weak self] in
            self?.expandedHUD = nil
        }
    }

    // MARK: - Countdown

    /// The timer button: opens or closes the minutes field while no countdown exists.
    func toggleCountdownEntry() {
        guard countdown == nil else { return }
        if isEditingCountdown {
            cancelCountdownEntry()
        } else {
            isEditingCountdown = true
        }
    }

    func cancelCountdownEntry() {
        guard isEditingCountdown else { return }
        isEditingCountdown = false
        collapseIfMouseLeft()
    }

    /// Starts a countdown from the minutes field; values outside 1...999 are ignored.
    func startCountdown(minutes: Int) {
        guard (1...999).contains(minutes) else { return }
        isEditingCountdown = false
        run(for: TimeInterval(minutes) * 60)
        collapseIfMouseLeft()
    }

    func pauseCountdown() {
        guard case .running(let endDate) = countdown else { return }
        countdownToken?.cancel()
        countdownToken = nil
        countdown = .paused(remaining: max(0, endDate.timeIntervalSince(now())))
    }

    func resumeCountdown() {
        guard case .paused(let remaining) = countdown else { return }
        run(for: remaining)
    }

    func cancelCountdown() {
        countdownToken?.cancel()
        countdownToken = nil
        countdown = nil
    }

    private func run(for duration: TimeInterval) {
        countdownToken?.cancel()
        countdown = .running(endDate: now().addingTimeInterval(duration))
        countdownToken = scheduler.schedule(after: duration) { [weak self] in self?.countdownFinished() }
    }

    private func countdownFinished() {
        countdownToken = nil
        countdown = nil
        present(.timerDone)
        onCountdownFinished?()
    }

    /// Editing kept the island open after the mouse left; close it the normal way now.
    private func collapseIfMouseLeft() {
        guard state == .expanded, !isHovering else { return }
        hoverToken?.cancel()
        hoverToken = scheduler.schedule(after: configuration.collapseDelay) { [weak self] in self?.collapse() }
    }
}
