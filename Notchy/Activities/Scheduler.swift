import Foundation

@MainActor
protocol SchedulerToken: AnyObject {
    func cancel()
}

/// One-shot delayed actions. Injected so tests can control time.
@MainActor
protocol Scheduler {
    @discardableResult
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> SchedulerToken
}

@MainActor
final class MainScheduler: Scheduler {
    private final class Token: SchedulerToken {
        var task: Task<Void, Never>?
        func cancel() { task?.cancel() }
    }

    @discardableResult
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> SchedulerToken {
        let token = Token()
        token.task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            action()
        }
        return token
    }
}
