import XCTest
@testable import Notchy

@MainActor
final class NotchViewModelTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!

    override func setUp() async throws {
        scheduler = ManualScheduler()
        vm = NotchViewModel(scheduler: scheduler)
    }

    private func expand() {
        vm.hoverChanged(true)
        scheduler.advance(by: vm.configuration.hoverDelay)
        XCTAssertEqual(vm.state, .expanded)
    }

    func testStartsClosed() {
        XCTAssertEqual(vm.state, .closed)
    }

    func testPeekClosesAfterPeekDuration() {
        vm.present(Fixtures.pluggedIn)
        XCTAssertEqual(vm.state, .peek(Fixtures.pluggedIn))
        scheduler.advance(by: 2.9)
        XCTAssertEqual(vm.state, .peek(Fixtures.pluggedIn))
        scheduler.advance(by: 0.2)
        XCTAssertEqual(vm.state, .closed)
    }

    func testHUDUsesShorterDuration() {
        vm.present(Fixtures.volume(0.5))
        scheduler.advance(by: 1.5)
        XCTAssertEqual(vm.state, .closed)
    }

    func testHigherPriorityReplacesCurrentPeek() {
        vm.present(Fixtures.pluggedIn)
        vm.present(Fixtures.volume(0.5))
        XCTAssertEqual(vm.state, .peek(Fixtures.volume(0.5)))
    }

    func testLowerPriorityWaitsForCurrentPeek() {
        vm.present(Fixtures.volume(0.5))
        vm.present(Fixtures.pluggedIn)
        XCTAssertEqual(vm.state, .peek(Fixtures.volume(0.5)))
        scheduler.advance(by: 1.5)
        XCTAssertEqual(vm.state, .peek(Fixtures.pluggedIn))
        scheduler.advance(by: 3.0)
        XCTAssertEqual(vm.state, .closed)
    }

    func testOnlyLatestPendingPeekIsKept() {
        vm.present(Fixtures.volume(0.5))
        vm.present(Fixtures.pluggedIn)
        vm.present(Fixtures.airpods)
        scheduler.advance(by: 1.5)
        XCTAssertEqual(vm.state, .peek(Fixtures.airpods))
        scheduler.advance(by: 3.0)
        XCTAssertEqual(vm.state, .closed)
    }

    func testRepeatedHUDUpdatesValueAndResetsTimer() {
        vm.present(Fixtures.volume(0.5))
        scheduler.advance(by: 1.0)
        vm.present(Fixtures.volume(0.6))
        XCTAssertEqual(vm.state, .peek(Fixtures.volume(0.6)))
        scheduler.advance(by: 1.0)
        XCTAssertEqual(vm.state, .peek(Fixtures.volume(0.6)))
        scheduler.advance(by: 0.6)
        XCTAssertEqual(vm.state, .closed)
    }

    func testHoverExpandsAfterDelay() {
        vm.hoverChanged(true)
        XCTAssertEqual(vm.state, .closed)
        scheduler.advance(by: 0.1)
        XCTAssertEqual(vm.state, .expanded)
    }

    func testLeavingBeforeDelayDoesNotExpand() {
        vm.hoverChanged(true)
        scheduler.advance(by: 0.05)
        vm.hoverChanged(false)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(vm.state, .closed)
    }

    func testLeavingCollapsesAfterDelay() {
        expand()
        vm.hoverChanged(false)
        scheduler.advance(by: 0.29)
        XCTAssertEqual(vm.state, .expanded)
        scheduler.advance(by: 0.02)
        XCTAssertEqual(vm.state, .closed)
    }

    func testReenteringCancelsCollapse() {
        expand()
        vm.hoverChanged(false)
        scheduler.advance(by: 0.2)
        vm.hoverChanged(true)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(vm.state, .expanded)
    }

    func testExpandingDiscardsPeekAndPending() {
        vm.present(Fixtures.volume(0.5))
        vm.present(Fixtures.pluggedIn)
        expand()
        vm.hoverChanged(false)
        scheduler.advance(by: 10)
        XCTAssertEqual(vm.state, .closed)
    }

    func testNonHUDPeekIgnoredWhileExpanded() {
        expand()
        vm.present(Fixtures.pluggedIn)
        XCTAssertEqual(vm.state, .expanded)
        vm.hoverChanged(false)
        scheduler.advance(by: 10)
        XCTAssertEqual(vm.state, .closed)
    }

    func testHUDWhileExpandedShowsInlineHUD() {
        expand()
        vm.present(Fixtures.volume(0.7))
        XCTAssertEqual(vm.state, .expanded)
        XCTAssertEqual(vm.expandedHUD, HUDState(kind: .volume, level: 0.7))
        scheduler.advance(by: 1.5)
        XCTAssertNil(vm.expandedHUD)
    }

    func testSwipeSendsCommandsOnlyWhenExpandedWithMedia() {
        var sent: [MediaCommand] = []
        vm.mediaCommandHandler = { sent.append($0) }
        vm.handleSwipe(.left)
        vm.updateMedia(Fixtures.song)
        vm.handleSwipe(.left)
        XCTAssertEqual(sent, [])
        expand()
        vm.handleSwipe(.left)
        vm.handleSwipe(.right)
        XCTAssertEqual(sent, [.next, .previous])
    }

    func testConfigurationChangesDurations() {
        vm.configuration.peekDuration = 5
        vm.present(Fixtures.pluggedIn)
        scheduler.advance(by: 4.9)
        XCTAssertEqual(vm.state, .peek(Fixtures.pluggedIn))
        scheduler.advance(by: 0.2)
        XCTAssertEqual(vm.state, .closed)
    }
}
