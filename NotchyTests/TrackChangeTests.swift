import XCTest
@testable import Notchy

@MainActor
final class TrackChangeTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!

    override func setUp() async throws {
        scheduler = ManualScheduler()
        vm = NotchViewModel(scheduler: scheduler)
    }

    private func song(_ title: String, playing: Bool = true) -> MediaState {
        MediaState(title: title, artist: "Artist", isPlaying: playing, bundleIdentifier: "com.spotify.client")
    }

    func testFirstTrackIsNotAnnounced() {
        vm.updateMedia(song("One"))
        XCTAssertNil(vm.trackTitle)
    }

    func testNewTrackShowsItsTitleForAWhile() {
        vm.updateMedia(song("One"))
        vm.updateMedia(song("Two"))
        XCTAssertEqual(vm.trackTitle, "Two")
        XCTAssertTrue(vm.islandContent.showsTrackTitle)
        scheduler.advance(by: vm.configuration.trackTitleDuration)
        XCTAssertNil(vm.trackTitle)
    }

    func testPauseAndResumeAreNotAChange() {
        vm.updateMedia(song("One"))
        vm.updateMedia(song("One", playing: false))
        vm.updateMedia(song("One"))
        XCTAssertNil(vm.trackTitle)
    }

    func testTrackChangedWhilePausedIsNotAnnounced() {
        vm.updateMedia(song("One"))
        vm.updateMedia(song("Two", playing: false))
        XCTAssertNil(vm.trackTitle)
    }

    func testQuickSkipsRestartTheTimer() {
        vm.updateMedia(song("One"))
        vm.updateMedia(song("Two"))
        scheduler.advance(by: vm.configuration.trackTitleDuration - 1)
        vm.updateMedia(song("Three"))
        scheduler.advance(by: vm.configuration.trackTitleDuration - 0.5)
        XCTAssertEqual(vm.trackTitle, "Three")
    }

    func testTimerHidesTheTitle() {
        vm.updateMedia(song("One"))
        vm.updateMedia(song("Two"))
        vm.startStopwatch()
        XCTAssertFalse(vm.islandContent.showsTrackTitle)
    }
}
