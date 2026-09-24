import XCTest
@testable import Notchy

@MainActor
final class CountdownTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    override func setUp() async throws {
        let scheduler = ManualScheduler()
        let start = start
        self.scheduler = scheduler
        vm = NotchViewModel(scheduler: scheduler, now: { start.addingTimeInterval(scheduler.now) })
    }

    private func expand() {
        vm.hoverChanged(true)
        scheduler.advance(by: vm.configuration.hoverDelay)
        XCTAssertEqual(vm.state, .expanded)
    }

    func testTimerButtonTogglesTheMinutesField() {
        vm.toggleCountdownEntry()
        XCTAssertTrue(vm.isEditingCountdown)
        vm.toggleCountdownEntry()
        XCTAssertFalse(vm.isEditingCountdown)
    }

    func testTimerButtonDoesNothingWhileACountdownExists() {
        vm.startCountdown(minutes: 5)
        vm.toggleCountdownEntry()
        XCTAssertFalse(vm.isEditingCountdown)
    }

    func testStartingRunsUntilTheEndThenShowsTheDonePeek() {
        var finished = 0
        vm.onCountdownFinished = { finished += 1 }
        vm.toggleCountdownEntry()
        vm.startCountdown(minutes: 1)
        XCTAssertFalse(vm.isEditingCountdown)
        XCTAssertEqual(vm.countdown, .running(endDate: start.addingTimeInterval(60)))
        scheduler.advance(by: 59)
        XCTAssertNotNil(vm.countdown)
        scheduler.advance(by: 1)
        XCTAssertNil(vm.countdown)
        XCTAssertEqual(vm.state, .peek(.timerDone))
        XCTAssertEqual(finished, 1)
    }

    func testDonePeekStaysFiveSeconds() {
        vm.startCountdown(minutes: 1)
        scheduler.advance(by: 60)
        scheduler.advance(by: 4.9)
        XCTAssertEqual(vm.state, .peek(.timerDone))
        scheduler.advance(by: 0.1)
        XCTAssertEqual(vm.state, .closed)
    }

    func testMinutesOutsideTheRangeAreIgnored() {
        vm.toggleCountdownEntry()
        vm.startCountdown(minutes: 0)
        vm.startCountdown(minutes: 1000)
        XCTAssertNil(vm.countdown)
        XCTAssertTrue(vm.isEditingCountdown)
    }

    func testPauseAndResumeKeepTheRemainingTime() {
        vm.startCountdown(minutes: 1)
        scheduler.advance(by: 20)
        vm.pauseCountdown()
        XCTAssertEqual(vm.countdown, .paused(remaining: 40))
        scheduler.advance(by: 100)
        XCTAssertEqual(vm.countdown, .paused(remaining: 40), "a paused countdown must not finish")
        vm.resumeCountdown()
        XCTAssertEqual(vm.countdown, .running(endDate: start.addingTimeInterval(160)))
        scheduler.advance(by: 40)
        XCTAssertNil(vm.countdown)
    }

    func testCancelStopsTheCountdown() {
        var finished = 0
        vm.onCountdownFinished = { finished += 1 }
        vm.startCountdown(minutes: 1)
        vm.cancelCountdown()
        scheduler.advance(by: 120)
        XCTAssertNil(vm.countdown)
        XCTAssertEqual(finished, 0)
        XCTAssertEqual(vm.state, .closed)
    }

    func testIslandStaysOpenWhileEnteringMinutes() {
        expand()
        vm.toggleCountdownEntry()
        vm.hoverChanged(false)
        scheduler.advance(by: 10)
        XCTAssertEqual(vm.state, .expanded)
        vm.cancelCountdownEntry()
        scheduler.advance(by: vm.configuration.collapseDelay)
        XCTAssertEqual(vm.state, .closed)
    }

    func testIslandContentReportsTheCountdown() {
        vm.toggleCountdownEntry()
        XCTAssertEqual(vm.islandContent, IslandContent(), "the minutes field sits in the control row")
        vm.startCountdown(minutes: 5)
        XCTAssertEqual(vm.islandContent, IslandContent(hasCountdown: true))
    }

    func testFormat() {
        XCTAssertEqual(CountdownFormat.string(from: 59), "0:59")
        XCTAssertEqual(CountdownFormat.string(from: 299.2), "5:00")
        XCTAssertEqual(CountdownFormat.string(from: 3723), "1:02:03")
    }
}
