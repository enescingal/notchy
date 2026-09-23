import XCTest
@testable import Notchy

final class PeekFormattingTests: XCTestCase {
    func testVolumeSymbols() {
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .volume, level: 0.5, isMuted: true)), "speaker.slash.fill")
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .volume, level: 0)), "speaker.slash.fill")
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .volume, level: 0.2)), "speaker.wave.1.fill")
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .volume, level: 0.5)), "speaker.wave.2.fill")
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .volume, level: 0.9)), "speaker.wave.3.fill")
    }

    func testBrightnessSymbols() {
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .brightness, level: 0.2)), "sun.min.fill")
        XCTAssertEqual(HUDPeekView.symbolName(for: HUDState(kind: .brightness, level: 0.8)), "sun.max.fill")
    }

    func testBatterySymbols() {
        XCTAssertEqual(BatteryPeekView.symbolName(for: BatteryEvent(kind: .pluggedIn, percentage: 40, isCharging: true)), "battery.100percent.bolt")
        XCTAssertEqual(BatteryPeekView.symbolName(for: BatteryEvent(kind: .low, percentage: 10, isCharging: false)), "battery.0percent")
        XCTAssertEqual(BatteryPeekView.symbolName(for: BatteryEvent(kind: .unplugged, percentage: 30, isCharging: false)), "battery.25percent")
        XCTAssertEqual(BatteryPeekView.symbolName(for: BatteryEvent(kind: .unplugged, percentage: 95, isCharging: false)), "battery.100percent")
    }

    func testBluetoothSymbols() {
        XCTAssertEqual(BluetoothPeekView.symbolName(for: .airpodsPro), "airpodspro")
        XCTAssertEqual(BluetoothPeekView.symbolName(for: .headphones), "headphones")
    }

    func testBluetoothBatteryText() {
        XCTAssertNil(BluetoothPeekView.batteryText(nil))
        XCTAssertNil(BluetoothPeekView.batteryText(BluetoothBattery()))
        XCTAssertEqual(BluetoothPeekView.batteryText(BluetoothBattery(left: 80, right: 80)), "%80")
        XCTAssertEqual(BluetoothPeekView.batteryText(BluetoothBattery(left: 80, right: 75)), "S %80 · D %75")
        XCTAssertEqual(BluetoothPeekView.batteryText(BluetoothBattery(single: 60)), "%60")
        XCTAssertEqual(BluetoothPeekView.batteryText(BluetoothBattery(caseLevel: 50)), "Kutu %50")
    }
}
