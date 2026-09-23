import XCTest
@testable import Notchy

final class BatteryEventDetectorTests: XCTestCase {
    private func onBattery(_ percentage: Int) -> BatteryReading {
        BatteryReading(percentage: percentage, isCharging: false, isPluggedIn: false)
    }

    private func charging(_ percentage: Int) -> BatteryReading {
        BatteryReading(percentage: percentage, isCharging: true, isPluggedIn: true)
    }

    func testFirstReadingIsBaselineOnly() {
        var detector = BatteryEventDetector()
        XCTAssertNil(detector.process(onBattery(50)))
    }

    func testPlugAndUnplug() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(50))
        XCTAssertEqual(detector.process(charging(50)), BatteryEvent(kind: .pluggedIn, percentage: 50, isCharging: true))
        XCTAssertEqual(detector.process(onBattery(51)), BatteryEvent(kind: .unplugged, percentage: 51, isCharging: false))
    }

    func testRepeatedReadingProducesNothing() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(50))
        XCTAssertNil(detector.process(onBattery(50)))
        XCTAssertNil(detector.process(onBattery(49)))
    }

    func testEachThresholdAnnouncedOnce() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(21))
        XCTAssertEqual(detector.process(onBattery(20))?.kind, .low)
        XCTAssertNil(detector.process(onBattery(19)))
        XCTAssertEqual(detector.process(onBattery(10))?.kind, .low)
        XCTAssertNil(detector.process(onBattery(9)))
    }

    func testJumpingPastBothThresholdsAnnouncesOnce() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(25))
        XCTAssertEqual(detector.process(onBattery(9)), BatteryEvent(kind: .low, percentage: 9, isCharging: false))
        XCTAssertNil(detector.process(onBattery(8)))
    }

    func testPluggingInResetsThresholds() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(21))
        _ = detector.process(onBattery(20))
        _ = detector.process(charging(20))
        _ = detector.process(onBattery(50))
        XCTAssertEqual(detector.process(onBattery(20))?.kind, .low)
    }

    func testBaselineBelowThresholdDoesNotReannounceIt() {
        var detector = BatteryEventDetector()
        _ = detector.process(onBattery(15))
        XCTAssertNil(detector.process(onBattery(14)))
        XCTAssertEqual(detector.process(onBattery(10))?.kind, .low)
    }

    func testNoLowWarningWhilePluggedIn() {
        var detector = BatteryEventDetector()
        _ = detector.process(charging(25))
        XCTAssertNil(detector.process(BatteryReading(percentage: 15, isCharging: false, isPluggedIn: true)))
    }
}
