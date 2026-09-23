import XCTest
@testable import Notchy

final class RestartPolicyTests: XCTestCase {
    func testBackoffThenGiveUp() {
        var policy = RestartPolicy()
        XCTAssertEqual(policy.nextDelay(), 1)
        XCTAssertEqual(policy.nextDelay(), 2)
        XCTAssertEqual(policy.nextDelay(), 4)
        XCTAssertNil(policy.nextDelay())
    }

    func testResetStartsOver() {
        var policy = RestartPolicy()
        _ = policy.nextDelay()
        _ = policy.nextDelay()
        policy.reset()
        XCTAssertEqual(policy.nextDelay(), 1)
    }
}
