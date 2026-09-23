import XCTest
@testable import Notchy

private final class FakeAirPods: NSObject {
    @objc dynamic var batteryPercentLeft: UInt8 = 80
    @objc dynamic var batteryPercentRight: UInt8 = 75
    @objc dynamic var batteryPercentCase: UInt8 = 0
    @objc dynamic var batteryPercentSingle: UInt8 = 0
}

private final class FakeHeadphones: NSObject {
    @objc dynamic var batteryPercentSingle: UInt8 = 60
}

final class BluetoothBatteryReaderTests: XCTestCase {
    func testReadsAvailableValuesAndTreatsZeroAsUnknown() {
        XCTAssertEqual(BluetoothBatteryReader.read(from: FakeAirPods()), BluetoothBattery(left: 80, right: 75))
    }

    func testMissingSelectorsAreSkipped() {
        XCTAssertEqual(BluetoothBatteryReader.read(from: FakeHeadphones()), BluetoothBattery(single: 60))
    }

    func testNoValuesReturnsNil() {
        XCTAssertNil(BluetoothBatteryReader.read(from: NSObject()))
    }
}
