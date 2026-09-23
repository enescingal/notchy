import XCTest
@testable import Notchy

final class SmokeTests: XCTestCase {
    func testLogSubsystem() {
        XCTAssertEqual(Log.subsystem, "com.notchy")
    }
}
