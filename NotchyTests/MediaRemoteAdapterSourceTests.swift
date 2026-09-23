import XCTest
@testable import Notchy

@MainActor
private final class FakeStreamProcess: StreamProcess {
    var onOutput: ((Data) -> Void)?
    var onExit: ((Int32) -> Void)?
    private(set) var stopped = false

    func emit(_ line: String) {
        onOutput?(Data((line + "\n").utf8))
    }

    func exit(status: Int32 = 1) {
        onExit?(status)
    }

    func stop() {
        stopped = true
    }
}

/// Collects every fake process a test's `launchProcess` closure created, in launch order.
@MainActor
private final class LaunchLog {
    var launches: [FakeStreamProcess] = []

    func launch(_: URL, _: [String]) -> StreamProcess {
        let process = FakeStreamProcess()
        launches.append(process)
        return process
    }
}

@MainActor
final class MediaRemoteAdapterSourceTests: XCTestCase {
    /// A bundle whose Resources directory looks like it contains the vendored adapter,
    /// so `MediaRemoteAdapterSource.init?` succeeds without touching the real Vendor/ tree.
    private func makeFakeAdapterBundle() -> Bundle {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let adapterDir = root.appendingPathComponent("MediaRemoteAdapter")
        try! FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: adapterDir.appendingPathComponent("mediaremote-adapter.pl").path, contents: nil)
        try! FileManager.default.createDirectory(
            at: adapterDir.appendingPathComponent("MediaRemoteAdapter.framework"), withIntermediateDirectories: true)
        return Bundle(url: root)!
    }

    private func makeSource(scheduler: Scheduler, log: LaunchLog) -> MediaRemoteAdapterSource {
        MediaRemoteAdapterSource(bundle: makeFakeAdapterBundle(), scheduler: scheduler, launchProcess: log.launch)!
    }

    func testGivesUpAfterExhaustingBackoff() {
        let scheduler = ManualScheduler()
        let log = LaunchLog()
        let source = makeSource(scheduler: scheduler, log: log)
        var failureCount = 0
        source.onFailure = { failureCount += 1 }
        source.start()
        XCTAssertEqual(log.launches.count, 1)

        // The first three exits should each schedule a restart (delays 1, 2, 4) and NOT give
        // up, since RestartPolicy.delays has exactly 3 entries.
        let delays: [TimeInterval] = [1, 2, 4]
        for (index, delay) in delays.enumerated() {
            log.launches[index].emit(#"{"type":"data","diff":false,"payload":{}}"#)
            log.launches[index].exit(status: 1)
            XCTAssertEqual(failureCount, 0, "should not give up after only \(index + 1) exit(s)")
            scheduler.advance(by: delay)
        }
        XCTAssertEqual(log.launches.count, 4, "should have relaunched 3 times (4 total launches)")

        // The 4th exit exhausts the backoff: onFailure fires exactly once, no further restart.
        log.launches[3].emit(#"{"type":"data","diff":false,"payload":{}}"#)
        log.launches[3].exit(status: 1)
        XCTAssertEqual(failureCount, 1)
        scheduler.advance(by: 100)
        XCTAssertEqual(log.launches.count, 4, "should not launch again after giving up")
    }

    func testStayingUpResetsBackoff() {
        let scheduler = ManualScheduler()
        let log = LaunchLog()
        let source = makeSource(scheduler: scheduler, log: log)
        source.start()
        XCTAssertEqual(log.launches.count, 1)

        // First exit uses the first backoff delay (1s).
        log.launches[0].exit(status: 1)
        scheduler.advance(by: 1)
        XCTAssertEqual(log.launches.count, 2)

        // Stay up past the 10s stability window without exiting: the backoff should reset.
        scheduler.advance(by: 10)

        // A subsequent exit should use the *first* delay (1s) again, not the second (2s) —
        // proving the counter reset rather than continuing where it left off.
        log.launches[1].exit(status: 1)
        scheduler.advance(by: 1)
        XCTAssertEqual(log.launches.count, 3, "restart policy should have reset after staying up 10s")
    }

    func testIgnoresStaleOutputAndExitFromAReplacedProcess() {
        let scheduler = ManualScheduler()
        let log = LaunchLog()
        let source = makeSource(scheduler: scheduler, log: log)
        var updates: [MediaState?] = []
        source.onUpdate = { updates.append($0) }
        source.start()
        XCTAssertEqual(log.launches.count, 1)

        log.launches[0].exit(status: 1)
        scheduler.advance(by: 1)
        XCTAssertEqual(log.launches.count, 2)

        // Late output/exit from the replaced (first) process must be ignored.
        updates.removeAll()
        log.launches[0].emit(#"{"type":"data","diff":false,"payload":{"title":"Stale","artist":"","playing":true}}"#)
        XCTAssertTrue(updates.isEmpty)
        log.launches[0].exit(status: 0)
        XCTAssertEqual(log.launches.count, 2, "a stale exit must not trigger another relaunch")
    }
}
