import XCTest
@testable import Notchy

final class MediaKeyParserTests: XCTestCase {
    private func data1(key: Int, state: Int, repeat isRepeat: Bool = false) -> Int {
        (key << 16) | (state << 8) | (isRepeat ? 1 : 0)
    }

    func testVolumeUpKeyDown() {
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 0, state: 0x0A)),
                       MediaKeyEvent(key: .volumeUp, isDown: true, isRepeat: false))
    }

    func testKeyUp() {
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 1, state: 0x0B))?.isDown, false)
    }

    func testRepeatFlag() {
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 1, state: 0x0A, repeat: true))?.isRepeat, true)
    }

    func testMuteAndBrightness() {
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 7, state: 0x0A))?.key, .mute)
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 2, state: 0x0A))?.key, .brightnessUp)
        XCTAssertEqual(MediaKeyParser.parse(subtype: 8, data1: data1(key: 3, state: 0x0A))?.key, .brightnessDown)
    }

    func testIgnoresOtherKeysAndSubtypes() {
        XCTAssertNil(MediaKeyParser.parse(subtype: 8, data1: data1(key: 16, state: 0x0A))) // play/pause
        XCTAssertNil(MediaKeyParser.parse(subtype: 7, data1: data1(key: 0, state: 0x0A)))
    }

    func testBrightnessKeyCodes() {
        XCTAssertEqual(MediaKeyParser.brightnessKey(forKeyCode: 144), .brightnessUp)
        XCTAssertEqual(MediaKeyParser.brightnessKey(forKeyCode: 145), .brightnessDown)
        XCTAssertNil(MediaKeyParser.brightnessKey(forKeyCode: 0))
    }
}
