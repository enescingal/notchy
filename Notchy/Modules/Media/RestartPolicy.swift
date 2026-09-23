import Foundation

struct RestartPolicy {
    static let delays: [TimeInterval] = [1, 2, 4]
    private var attempts = 0

    /// Delay before the next restart, or nil when we should give up.
    mutating func nextDelay() -> TimeInterval? {
        guard attempts < Self.delays.count else { return nil }
        defer { attempts += 1 }
        return Self.delays[attempts]
    }

    mutating func reset() {
        attempts = 0
    }
}
