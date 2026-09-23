import XCTest
@testable import Notchy

final class HUDStepTests: XCTestCase {
    func testNormalStep() {
        XCTAssertEqual(HUDStep.next(from: 0.5, up: true, fine: false), 0.5625, accuracy: 1e-9)
        XCTAssertEqual(HUDStep.next(from: 0.5, up: false, fine: false), 0.4375, accuracy: 1e-9)
    }

    func testFineStep() {
        XCTAssertEqual(HUDStep.next(from: 0.5, up: true, fine: true), 0.515625, accuracy: 1e-9)
    }

    func testSnapsOffGridValuesBeforeStepping() {
        XCTAssertEqual(HUDStep.next(from: 0.52, up: true, fine: false), 0.5625, accuracy: 1e-9)
    }

    func testClampsToRange() {
        XCTAssertEqual(HUDStep.next(from: 1.0, up: true, fine: false), 1.0)
        XCTAssertEqual(HUDStep.next(from: 0.0, up: false, fine: false), 0.0)
    }
}
