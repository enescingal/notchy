import XCTest
@testable import Notchy

final class DeviceClassificationTests: XCTestCase {
    func testAirPodsVariantsByName() {
        XCTAssertEqual(DeviceKind.classify(name: "Enes'in AirPods Pro'su", majorClass: 0x04), .airpodsPro)
        XCTAssertEqual(DeviceKind.classify(name: "AirPods Max", majorClass: 0x04), .airpodsMax)
        XCTAssertEqual(DeviceKind.classify(name: "AirPods", majorClass: 0x04), .airpods)
    }

    func testGenericAudioDevice() {
        XCTAssertEqual(DeviceKind.classify(name: "WH-1000XM4", majorClass: 0x04), .headphones)
    }

    func testNonAudioDevice() {
        let kind = DeviceKind.classify(name: "Magic Mouse", majorClass: 0x05)
        XCTAssertEqual(kind, .other)
        XCTAssertFalse(kind.isAudio)
    }
}
