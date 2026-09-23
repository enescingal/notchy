import XCTest
@testable import Notchy

final class SwipeDetectorTests: XCTestCase {
    func testFiresOnceWhenThresholdCrossed() {
        var detector = SwipeDetector()
        XCTAssertNil(detector.process(phase: .began, fingerDeltaX: -10))
        XCTAssertNil(detector.process(phase: .changed, fingerDeltaX: -20))
        XCTAssertEqual(detector.process(phase: .changed, fingerDeltaX: -15), .left)
        XCTAssertNil(detector.process(phase: .changed, fingerDeltaX: -50))
    }

    func testRightSwipe() {
        var detector = SwipeDetector()
        _ = detector.process(phase: .began, fingerDeltaX: 30)
        XCTAssertEqual(detector.process(phase: .changed, fingerDeltaX: 15), .right)
    }

    func testSmallMovementNeverFires() {
        var detector = SwipeDetector()
        XCTAssertNil(detector.process(phase: .began, fingerDeltaX: 10))
        XCTAssertNil(detector.process(phase: .changed, fingerDeltaX: 10))
        XCTAssertNil(detector.process(phase: .ended, fingerDeltaX: 0))
    }

    func testEndResetsForNextGesture() {
        var detector = SwipeDetector()
        _ = detector.process(phase: .began, fingerDeltaX: -45)
        _ = detector.process(phase: .ended, fingerDeltaX: 0)
        XCTAssertEqual(detector.process(phase: .began, fingerDeltaX: -45), .left)
    }
}
