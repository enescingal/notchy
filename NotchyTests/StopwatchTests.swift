import XCTest
@testable import Notchy

@MainActor
final class StopwatchTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    override func setUp() async throws {
        let scheduler = ManualScheduler()
        let start = start
        self.scheduler = scheduler
        vm = NotchViewModel(scheduler: scheduler, now: { start.addingTimeInterval(scheduler.now) })
    }

    func testButtonStartsTheStopwatchOnce() {
        vm.startStopwatch()
        XCTAssertEqual(vm.stopwatch, .running(startDate: start))
        scheduler.advance(by: 10)
        vm.startStopwatch()
        XCTAssertEqual(vm.stopwatch, .running(startDate: start), "a running stopwatch must not restart")
    }

    func testPauseAndResumeKeepTheElapsedTime() {
        vm.startStopwatch()
        scheduler.advance(by: 20)
        vm.pauseStopwatch()
        XCTAssertEqual(vm.stopwatch, .paused(elapsed: 20))
        scheduler.advance(by: 100)
        XCTAssertEqual(vm.stopwatch, .paused(elapsed: 20))
        vm.resumeStopwatch()
        XCTAssertEqual(vm.stopwatch, .running(startDate: start.addingTimeInterval(100)))
    }

    func testResetRemovesTheStopwatch() {
        vm.startStopwatch()
        vm.resetStopwatch()
        XCTAssertNil(vm.stopwatch)
    }

    func testStopwatchAndCountdownRunTogether() {
        vm.startCountdown(minutes: 1)
        vm.startStopwatch()
        XCTAssertEqual(vm.islandContent, IslandContent(hasCountdown: true, hasStopwatch: true))
        XCTAssertEqual(vm.islandContent.expandedRows, 3)
    }

    func testElapsedFormatRoundsDown() {
        XCTAssertEqual(CountdownFormat.string(from: 59.9, rounding: .down), "0:59")
        XCTAssertEqual(CountdownFormat.string(from: 3723.5, rounding: .down), "1:02:03")
    }
}
