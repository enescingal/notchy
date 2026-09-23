import XCTest
@testable import Notchy

@MainActor
private final class FakeMediaSource: MediaSource {
    var onUpdate: ((MediaState?) -> Void)?
    var onFailure: (() -> Void)?
    var started = false
    var stopped = false
    var sent: [MediaCommand] = []

    func start() { started = true }
    func stop() { stopped = true }
    func send(_ command: MediaCommand) { sent.append(command) }
}

@MainActor
final class MediaModuleTests: XCTestCase {
    private var viewModel: NotchViewModel!
    private var status: ModuleStatus!
    private var source: FakeMediaSource!

    override func setUp() async throws {
        viewModel = NotchViewModel(scheduler: ManualScheduler())
        status = ModuleStatus()
        source = FakeMediaSource()
    }

    private func makeModule() -> MediaModule {
        MediaModule(viewModel: viewModel, status: status, makeSource: { [source] in source })
    }

    func testForwardsUpdatesAndCommands() {
        let module = makeModule()
        module.start()
        XCTAssertTrue(source.started)
        source.onUpdate?(Fixtures.song)
        XCTAssertEqual(viewModel.media, Fixtures.song)
        viewModel.send(.togglePlayPause)
        XCTAssertEqual(source.sent, [.togglePlayPause])
    }

    func testFailureMarksUnavailableAndClearsMedia() {
        let module = makeModule()
        module.start()
        source.onUpdate?(Fixtures.song)
        source.onFailure?()
        XCTAssertTrue(status.mediaUnavailable)
        XCTAssertNil(viewModel.media)
    }

    func testMissingSourceMarksUnavailable() {
        let module = MediaModule(viewModel: viewModel, status: status, makeSource: { nil })
        module.start()
        XCTAssertTrue(status.mediaUnavailable)
    }

    func testStopClearsState() {
        let module = makeModule()
        module.start()
        source.onUpdate?(Fixtures.song)
        module.stop()
        XCTAssertTrue(source.stopped)
        XCTAssertNil(viewModel.media)
        XCTAssertNil(viewModel.mediaCommandHandler)
    }
}
