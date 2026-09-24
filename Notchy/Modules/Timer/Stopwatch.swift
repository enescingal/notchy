import Foundation

/// A stopwatch counting up, started from the island.
enum StopwatchState: Equatable {
    case running(startDate: Date)
    case paused(elapsed: TimeInterval)

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
