import Foundation

/// A countdown started from the island.
enum CountdownState: Equatable {
    case running(endDate: Date)
    case paused(remaining: TimeInterval)

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

enum CountdownFormat {
    /// `m:ss`, or `h:mm:ss` from one hour up. Partial seconds round up by default, so a
    /// countdown's 0.4 s shows 0:01; a stopwatch rounds down instead.
    static func string(from seconds: TimeInterval, rounding: FloatingPointRoundingRule = .up) -> String {
        let total = max(0, Int(seconds.rounded(rounding)))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
