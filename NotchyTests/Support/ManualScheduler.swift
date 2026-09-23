import Foundation
@testable import Notchy

@MainActor
final class ManualScheduler: Scheduler {
    final class Token: SchedulerToken {
        let fireAt: TimeInterval
        let action: @MainActor () -> Void
        var isCancelled = false

        init(fireAt: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.fireAt = fireAt
            self.action = action
        }

        func cancel() { isCancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var tokens: [Token] = []

    @discardableResult
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> SchedulerToken {
        let token = Token(fireAt: now + delay, action: action)
        tokens.append(token)
        return token
    }

    /// Fires every non-cancelled action due within `interval`, in time order.
    func advance(by interval: TimeInterval) {
        let target = now + interval
        while let next = tokens
            .filter({ !$0.isCancelled && $0.fireAt <= target + 1e-9 })
            .min(by: { $0.fireAt < $1.fireAt }) {
            now = next.fireAt
            tokens.removeAll { $0 === next }
            next.action()
        }
        now = target
        tokens.removeAll { $0.isCancelled }
    }
}
